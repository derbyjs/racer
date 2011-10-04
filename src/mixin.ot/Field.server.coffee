text = require 'share/lib/types/text'
syncqueue = require 'share/lib/server/syncqueue'
FieldConnection = require './FieldConnection.server'

# DB needs to keep around
# data: {type, v, snapshot, meta}
# ops: [op]

Field = module.exports = (adapter, pubSub, path, @version, @type = text) ->
  @adapter = adapter
  @path = path

  @snapshot = ''
  @meta = {}
  @ops = []

  # Maps socketId -> fieldConnection
  @connections = {}

  # Used in @applyOp
  @applyQueue = syncqueue ({op, v: opVersion, meta: opMeta}, callback) =>
    # @getSnapshot (docData) ->

    opMeta ||= {}
    opMeta.ts = Date.now()

    if opVersion > @version
      return callback new Error 'Op at future version'

    if opVersion < @version
      # Transform the op to the current version of the document
      ops = @getOps opVersion
      try
        for realOp in ops
          op = @type.transform op, realOp.op, 'left'
          opVersion++
      catch err
        return callback err

    try
      @snapshot = @type.apply @snapshot, op
    catch err
      return callback err
    newOpData = {@path, op, meta: opMeta, v: opVersion}
    newDocData = {@snapshot, type: @type.name, v: opVersion+1, meta: @meta}
    @ops.push {op, v: opVersion, meta: opMeta}

    pubSub.publish @path, ot: newOpData
    callback null, opVersion

#    adapter.applyOT path, newOpData, newDocData, ->
#      # TODO Emit to other windows (path, newOpData)
#      @field.connections.emit 'otOp', newOpData
#      callback null, opVersion
  return

Field ::=
  getSnapshot: (callback) ->
    # TODO Separate adapter.get version return (which is really for stm purposes) from adapter.get for use with OT (See adapters/Memory)
    otPath = 'OT.' + @path
    @adapter.get otPath, (err, val, ver) ->
      if val is undefined
        @adapter.set otPath, val, ot: true, (err, val) ->
      # TODO

  applyOp: (opData, callback) ->
    process.nextTick => @applyQueue opData, callback

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

  getOps: (start, end = @version) -> @ops[start...end]
