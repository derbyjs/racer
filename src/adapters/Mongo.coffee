url = require 'url'
mongo = require 'mongodb'
EventEmitter = require('events').EventEmitter
ObjectId = mongo.BSONPure.ObjectID
ObjectId.toString = (oid) -> oid.toHexString()
ObjectId.fromString = (str) -> @createFromHexString str

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
module.exports = MongoAdapter = (conf) ->
  EventEmitter.call this
  @_ver = 0

  @_loadConf conf if conf

  @_state = DISCONNECTED

  @_collections = {}

  @_pending = []

  return

MongoAdapter:: =
  _loadConf: (conf) ->
    if typeof conf == 'string'
      uri = url.parse conf
      @_host = uri.hostname
      @_port = uri.port || 27017
      # TODO callback
      @_database = uri.pathname.replace /\//g, ''
      [@_user, @_pass] = uri.auth?.split(':') ? []
    else
      {@_host, @_port, @_database, @_user, @_pass} = conf

  connect: (conf, callback) ->
    if 'function' == typeof conf
      callback = conf
    else
      @_loadConf conf
    @_db = new mongo.Db(
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
        for todo in @_pending
          @[todo[0]].apply @, todo[1]
        @_pending = []
      if @_user && @_pass
        return @_db.authenticate @_user, @_pass, open
      return open()

  disconnect: (callback) ->
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

  # TODO create (new docs with auto-id's)
  #      Perhaps use "namespace.?.path.val"

  set: (path, val, ver, callback) ->
    return @_pending.push ['set', arguments] if @_state != CONNECTED
    [collection, id, path...] = path.split '.'
    if path.length
      path = path.join '.'
      delta = {ver: ver}
      delta[path] = val
      return @_collection(collection).update {_id: id}, { $set: delta}, { upsert: true, safe: true }, callback
    @_collection(collection).update {_id: id}, val, { safe: true }, callback

  del: (path, ver, callback) ->
    return @_pending.push ['del', arguments] if @_state != CONNECTED
    [collection, id, path...] = path.split '.'
    if path.length
      path = path.join '.'
      unset = {}
      unset[path] = 1
      return @_collection(collection).update {_id: id}, { $unset: unset }, { safe: true}, callback
    @_collection(collection).remove {_id: id}, callback

  get: (path,callback) ->
    return @_pending.push ['get', arguments] if @_state != CONNECTED
    [collection, id, path...] = path.split '.'
    if path.length
      path = path.join '.'
      fields = { _id: 0, ver: 1 }
      fields[path] = 1
      return @_collection(collection).findOne {_id: id}, { fields: fields }, (err, doc) ->
        return callback err if err
        # TODO Fix doc[path] with a lookup
        callback null, doc && doc[path], doc && doc.ver
    @_collection(collection).findOne {_id: id}, (err, doc) ->
      return callback err if err
      ver = doc && doc.ver
      delete doc.ver if doc
      callback null, doc, ver

  _collection: (name) ->
    @_collections[name] ||= new Collection name, @_db

  _genObjectId: ->
    ObjectId.toString(new ObjectId)

MongoAdapter.prototype.__proto__ = EventEmitter.prototype

# MongoCollection = require ('../../node_modules/mongodb/lib/mongodb').Collection
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
  onReady: () ->
    for todo in @_pending
      @[todo[0]].apply @, todo[1]
    @_pending = []

for name, fn of MongoCollection::
  do (name, fn) ->
    Collection::[name] = () ->
      collection = @collection
      args = arguments
      if @_ready
        process.nextTick ->
          collection[name].apply collection, args
      else
        @_pending.push [name, arguments]
