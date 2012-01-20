url = require 'url'
mongo = require 'mongodb'
NativeObjectId = mongo.BSONPure.ObjectID
{EventEmitter} = require 'events'

DISCONNECTED  = 1
CONNECTING    = 2
CONNECTED     = 3
DISCONNECTING = 4

# Examples:
# new MongoAdapter 'mongodb://localhost:port/database'
# new MongoAdapter
#   host: 'localhost'
#   port: 27017
#   database: 'example'
MongoAdapter = module.exports = (conf) ->
  EventEmitter.call @
  @_loadConf conf if conf
  @_state = DISCONNECTED
  @_collections = {}
  @_pending = []

  # TODO Make version scale beyond 1 db
  #      by sharding and with a vector
  #      clock with each member the
  #      version of a shard
  @version = 0

  return

MongoAdapter:: =
  __proto__: EventEmitter::

  _loadConf: (conf) ->
    if typeof conf is 'string'
      uri = url.parse conf
      @_host = uri.hostname
      @_port = uri.port || 27017
      # TODO callback
      @_database = uri.pathname.replace /\//g, ''
      [@_user, @_pass] = uri.auth?.split(':') ? []
    else
      {@_host, @_port, @_database, @_user, @_pass} = conf

  connect: (conf, callback) ->
    if typeof conf is 'function'
      callback = conf
    else if conf isnt undefined
      @_loadConf conf
    @_db ||= new mongo.Db(
        @_database
      , new mongo.Server @_host, @_port
    )
    @_state = CONNECTING
    @emit 'connecting'
    @_db.open (err) =>
      return callback err if err && callback
      open = =>
        @_state = CONNECTED
        @emit 'connected'
        for [method, args] in @_pending
          @[method].apply @, args
        @_pending = []

      if @_user && @_pass
        return @_db.authenticate @_user, @_pass, open
      return open()

  disconnect: (callback) ->
    collection._ready = false for _, collection of @_collections

    switch @_state
      when DISCONNECTED then callback null
      when CONNECTING then @once 'connected', => @close callback
      when CONNECTED
        @_state = DISCONNECTING
        @_db.close()
        @_state = DISCONNECTED
        @emit 'disconnected'
        # TODO onClose callbacks for collections
        callback() if callback
      when DISCONNECTING then @once 'disconnected', => callback null

  flush: (callback) ->
    return @_pending.push ['flush', arguments] if @_state != CONNECTED
    @_db.dropDatabase (err, done) ->
      throw err if err
      callback()

  # Mutator methods called via CustomDataSource::applyOps
  update: (collection, conds, op, opts, callback) ->
    @_collection(collection).update conds, op, opts, callback

  insert: (collection, json, opts, callback) ->
    # TODO Leverage pkey flag; it may not be _id
    json._id ||= new NativeObjectId
    @_collection(collection).insert json, opts, (err) ->
      return callback err if err
      callback null, {_id: json._id}

  remove: (collection, conds, callback) ->
    @_collection(collection).remove conds, (err) ->
      return callback err if err

  # Callback here receives raw json data back from Mongo
  findOne: (collection, conds, opts, callback) ->
    @_collection(collection).findOne conds, opts, callback

  find: (collection, conds, opts, callback) ->
    @_collection(collection).find conds, opts, (err, cursor) ->
      return callback err if err
      cursor.toArray (err, docs) ->
        return callback err if err
        return callback null, docs

  # Finds or creates the Mongo collection
  _collection: (name) ->
    @_collections[name] ||= new Collection name, @_db

  setVersion: (ver) -> @version = Math.max @version, ver

  setupDefaultPersistenceRoutes: (store) ->
    adapter = @

    idFor = (id) ->
      try
        return new NativeObjectId id
      catch e
        throw e unless e.message == 'Argument passed in must be a single String of 12 bytes or a string of 24 hex characters in hex format'
      return id

    store.defaultRoute 'get', '*.*.*', (collection, _id, relPath, done, next) ->
      only = {}
      only[relPath] = 1
      adapter.findOne collection, {_id}, only, (err, doc) ->
        return done err if err
        return done null, undefined, adapter.version if doc is null

        val = doc
        parts = relPath.split '.'
        val = val[prop] for prop in parts

        done null, val, adapter.version

    store.defaultRoute 'get', '*.*', (collection, _id, done, next) ->
      adapter.findOne collection, {_id}, {}, (err, doc) ->
        return done err if err
        return done null, undefined, adapter.version if doc is null
        delete doc.ver

        doc.id = doc._id.toString()
        delete doc._id

        done null, doc, adapter.version

    store.defaultRoute 'get', '*', (collection, done, next) ->
      adapter.find collection, {}, {}, (err, docs) ->
        return done err if err
        docsById = {}
        for doc in docs
          doc.id = doc._id.toString()
          delete doc._id
          delete doc.ver
          docsById[doc.id] = doc
        done null, docsById, adapter.version

    store.defaultRoute 'set', '*.*.*', (collection, _id, relPath, val, ver, done, next) ->
      (setTo = {})[relPath] = val
      op = $set: setTo
      _id = idFor _id
      adapter.update collection, {_id}, op, upsert: true, (err) ->
        return done err if err
        adapter.setVersion ver
        done()

    store.defaultRoute 'set', '*.*', (collection, _id, doc, ver, done, next) ->
      cb = (err) ->
        return done err if err
        adapter.setVersion ver
        done()
      if _id
        doc._id = _id = idFor _id
        delete doc.id
        adapter.update collection, {_id}, doc, upsert: true, cb
      else
        adapter.insert collection, doc, {}, cb

    store.defaultRoute 'del', '*.*.*', (collection, _id, relPath, ver, done, next) ->
      (unsetConf = {})[relPath] = 1
      op = $unset: unsetConf
      op.$inc = {ver: 1}
      _id = idFor _id
      adapter.update collection, {_id}, op, {}, (err) ->
        return done err if err
        adapter.setVersion ver
        done()

    store.defaultRoute 'del', '*.*', (collection, _id, ver, done, next) ->
      adapter.remove collection, {_id}, (err) ->
        return done err if err
        adapter.setVersion ver
        done()

    store.defaultRoute 'push', '*.*.*', (collection, _id, relPath, vals..., ver, done, next) ->
      op = $inc: {ver: 1}
      if vals.length == 1
        (op.$push = {})[relPath] = vals[0]
      else
        (op.$pushAll = {})[relPath] = vals

      op.$inc = {ver: 1}

      _id = idFor _id
#      isLocalId = /^\$_\d+_\d+$/
#      if isLocalId.test _id
#        clientId = _id
#        _id = new NativeObjectId
#      else
#        _id = new NativeObjectId _id

      adapter.update collection, {_id}, op, upsert: true, (err) ->
        return done err if err
        adapter.setVersion ver
        done null
#        return done null unless clientId
#        idMap = {}
#        idMap[clientId] = _id
#        done null, idMap

    store.defaultRoute 'unshift', '*.*.*', (collection, _id, relPath, globalVer, done, next) ->
      opts = ver: 1
      opts[relPath] = 1
      _id = idFor _id
      do exec = ->
        adapter.findOne collection, {_id}, opts, (err, found) ->
          return done err if err
          arr = found[relPath]
          ver = found.ver
          arr.unshift()
          (setTo = {})[relPath] = arr
          op = $set: setTo, $inc: {ver: 1}
          adapter.update collection, {_id, ver}, op, {}, (err) ->
            return exec() if err
            adapter.setVersion globalVer
            done()

    store.defaultRoute 'insert', '*.*.*', (collection, _id, relPath, index, vals..., globalVer, done, next) ->
      opts = ver: 1
      opts[relPath] = 1
      _id = idFor _id
      do exec = ->
        adapter.findOne collection, {_id}, opts, (err, found) ->
          return done err if err
          arr = found[relPath]
          arr.splice index, 0, vals...
          (setTo = {})[relPath] = arr
          op = $set: setTo, $inc: {ver: 1}
          ver = found.ver
          adapter.update collection, {_id, ver}, op, {}, (err) ->
            return exec() if err
            adapter.setVersion globalVer
            done()

    store.defaultRoute 'pop', '*.*.*', (collection, _id, relPath, ver, done, next) ->
      _id = idFor _id
      (popConf = {ver: 1})[relPath] = 1
      op = $pop: popConf, $inc: {ver: 1}
      adapter.update collection, {_id}, op, {}, (err) ->
        return done err if err
        adapter.setVersion ver
        done null

    store.defaultRoute 'shift', '*.*.*', (collection, _id, relPath, globalVer, done, next) ->
      opts = ver: 1
      opts[relPath] = 1
      _id = idFor _id
      do exec = ->
        adapter.findOne collection, {_id}, opts, (err, found) ->
          return done err if err
          arr = found[relPath]
          arr.shift()
          (setTo = {})[relPath] = arr
          op = $set: setTo, $inc: {ver: 1}
          ver = found.ver
          adapter.update collection, {_id, ver}, op, {}, (err) ->
            return exec() if err
            adapter.setVersion globalVer
            done null

    store.defaultRoute 'remove', '*.*.*', (collection, _id, relPath, index, count, globalVer, done, next) ->
      opts = ver: 1
      opts[relPath] = 1
      _id = idFor _id
      do exec = ->
        adapter.findOne collection, {_id}, opts, (err, found) ->
          return done err if err
          arr = found[relPath]
          arr.splice index, count
          (setTo = {})[relPath] = arr
          op = $set: setTo, $inc: {ver: 1}
          ver = found.ver
          adpater.update collection, {_id, ver}, op, {}, (err) ->
            return exec() if err
            adapter.setVersion globalVer
            done()

    store.defaultRoute 'move', '*.*.*', (collection, _id, relPath, from, to, globalVer, done, next) ->
      opts = ver: 1
      opts[relPath] = 1
      _id = idFor _id
      do exec = ->
        adapter.findOne collection, {_id}, opts, (err, found) ->
          return done err if err
          arr = found[relPath]
          [value] = arr.splice from, 1
          arr.splice to, 0, value
          (setTo = {})[relPath] = arr
          op = $set: setTo, $inc: {ver: 1}
          ver = found.ver
          adapter.update collection, {_id, ver}, op, {}, (err) ->
            return exec() if err
            adapter.setVersion globalVer
            done()

MongoCollection = mongo.Collection

Collection = (name, db) ->
  self = this
  self.name = name
  self.db = db
  self._pending = []
  self._ready = false

  db.collection name, (err, collection) ->
    throw err if err
    self._ready = true
    self.collection = collection
    self.onReady()

  return

Collection:: =
  onReady: ->
    for todo in @_pending
      @[todo[0]].apply @, todo[1]
    @_pending = []

for name, fn of MongoCollection::
  do (name, fn) ->
    Collection::[name] = ->
      collection = @collection
      args = arguments
      if @_ready
        process.nextTick ->
          collection[name].apply collection, args
      else
        @_pending.push [name, arguments]
