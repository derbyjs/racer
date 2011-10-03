text = require 'share/lib/types/text'
syncqueue = require 'share/lib/server/syncqueue'
FieldConnection = require './FieldConnection.server'

# DB needs to keep around
# data: {type, v, snapshot, meta}
# ops: [op]

Field = module.exports = (adapter, path, @version, @type = text) ->
  @adapter = adapter
  @path = path

  # Maps socketId -> fieldConnection
  @connections = {}
  Object.defineProperty @connections, 'emit',
    enumerable: false
    value: (channel, data) ->
      for socketId, client of @
        client.socket.emit channel, data

  # Used in @applyOp
  @queue = syncqueue ({op, v, meta}, callback) =>
    @getSnapshot (docData) ->
      return callback new Error 'Document does not exist' unless docData
      meta ||= {}
      meta.ts = Date.now()

      {v: version, snapshot, type} = docData

      submit = ->
        try
          snapshot = type.apply docData.snapshot, op
        catch err
          return callback err
        newOpData = {op, meta, v}
        newDocData = {snapshot, type: type.name, v: v+1, meta: docData.meta}
        adapter.applyOT path, newOpData, newDocData, ->
          # TODO Emit to other windows (path, newOpData)
          @field.connections.emit 'otOp', newOpData
          callback()
  return

Field ::=
  getSnapshot: (callback) ->
    # TODO Separate adapter.get version return (which is really for stm purposes) from adapter.get for use with OT (See adapters/Memory)
    @adapter.get 'ot.' + @path, (err, val, ver) ->
      # TODO

  applyOp: (opData, callback) ->
    process.nextTick => @queue opData, callback

  registerSocket: (socket, ver) ->
    client = new FieldConnection @, socket
    if ver?
      # TODO Test out race conditions e.g., if we request to listen since ver and then miss some ops after
      client.listenSinceVer ver ? null
    @connections[socket.id] = client
    return client

  unregisterSocket: (socket) ->
    delete @connections[socket.id]

  client: (socketId) -> @connections[socketId]
