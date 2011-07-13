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

  if typeof conf == 'string'
    uri = url.parse conf
    @_host = uri.hostname
    @_port = uri.port || 27017
    # TODO callback
    @_database = uri.pathname.replace /\//g, ''
    [@_user, @_pass] = uri.auth?.split(':') ? []
  else
    {@_host, @_port, @_database, @_user, @_pass} = conf.host

  @_state = DISCONNECTED

  @_collections = {}

  @_pending = []

  return

MongoAdapter:: =
  connect: (callback) ->
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
    [collection, id, path...] = @_extract path
    if path
      path = path.join '.'
      delta = {ver: ver}
      delta[path] = val
      return @_collection(collection).update {_id: id}, { $set: delta}, { safe: true }, callback
    @_collection(collection).update {_id: id}, val, { safe: true }, callback

  del: (path, ver, callback) ->
    return @_pending.push ['del', arguments] if @_state != CONNECTED
    [collection, id, path...] = @_extract path
    if path
      path = path.join '.'
      unset = {}
      unset[path] = 1
      return @_collection(collection).update {_id: id}, { $unset: unset }, { safe: true}, callback
    @_collection(collection).remove {_id: id}, callback

  get: (path,callback) ->
    return @_pending.push ['get', arguments] if @_state != CONNECTED
    [collection, id, path...] = @_extract path
    if path
      path = path.join '.'
      fields = { _id: 0, ver: 1 }
      fields[path] = 1
      return @_collection(collection).findOne {_id: id}, { fields: fields }, (err, doc) ->
        return callback err if err
        # TODO Fix doc[path] with a lookup
        callback null, doc[path], doc.ver
    @_collection(collection).findOne {_id: id}, {}, (err, doc) ->
      return callback err if err
      ver = doc.ver
      delete doc.ver
      callback null, doc, ver

  _collection: (name) ->
    @_collections[name] ||= new mongo.Collection name, @_db

  _genObjectId: ->
    ObjectId.toString new ObjectId

MongoAdapter.prototype.__proto__ = EventEmitter.prototype
