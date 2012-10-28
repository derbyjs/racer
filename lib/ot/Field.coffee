text = require '../../node_modules/share/lib/types/text'
Promise = require '../util/Promise'
Serializer = require '../Serializer'
{isSpeculative} = require '../util/speculative'

Field = module.exports = (@model, @path, @version = 0, @type = text) ->
  # @type.apply(snapshot, op)
  # @type.transform(op1, op2, side)
  # @type.normalize(op)
  # @type.create() -> ''

  @snapshot = null
  @queue = []
  @pendingOp = null
  @pendingCallbacks = []
  @inflightOp = null
  @inflightCallbacks = []
  @serverOps = {}

  # Avoids race condition where another browser's op
  # was accepted before an op submitted by this browser,
  # but this browser receives its op ack before Redis
  # propagates and sends notification of the other
  # browser's op to this browser. This avoids
  # "Invalid version" errors
  @incomingSerializer = new Serializer
    init: @version
    withEach: ([op, isRemote, err], ver) =>
      if isRemote
        docOp = op
        if @inflightOp
          [@inflightOp, docOp] = @xf @inflightOp, docOp
        if @pendingOp
          [@pendingOp, docOp] = @xf @pendingOp, docOp

        @version++
        @otApply docOp, false
      else
        # TODO console.log arguments
        oldInflightOp = @inflightOp
        @inflightOp = null
        if err
          unless @type.invert
            throw new Error "Op apply failed (#{err}) and the OT type does not define an invert function."

          # TODO make this throw configurable on/off
          throw new Error err

          undo = @type.invert oldInflightOp
          if @pendingOp
            [@pendingOp, undo] = @xf @pendingOp, undo
          @otApply undo
          callback err for callback in @inflightCallbacks
          return @flush

        unless ver == @version
          throw new Error 'Invalid version from server'

        @serverOps[@version] = oldInflightOp
        @version++
        callback null, oldInflightOp for callback in @inflightCallbacks
        @flush()
    timeout: 5000
    onTimeout: ->
      throw new Error "Did not receive a prior op in time. Invalid version would result by applying buffered received ops unless prior op was applied first."

  model.on 'change', ([_path, op, oldSnapshot], isLocal) ->
    return unless _path == path
    for {p, i, d} in op
      if i
        model.emit 'otInsert', [path, p, i], isLocal
      else
        model.emit 'otDel', [path, p, d], isLocal
    return

  return

Field:: =
  onRemoteOp: (op, v) ->
    return if v < @version
    throw new Error "Expected version #{@version} but got #{v}" unless v == @version
    docOp = @serverOps[@version] = op

    @incomingSerializer.add [docOp, true], v

  otApply: (docOp, isLocal = true) ->
    oldSnapshot = @snapshot
    @snapshot = @type.apply oldSnapshot, docOp
    @model.emit 'change', [@path, docOp, oldSnapshot], isLocal
    return @snapshot

  submitOp: (op, callback) ->
    type = @type
    op = type.normalize op
    @otApply op
    @pendingOp = if @pendingOp then type.compose @pendingOp, op else op
    @pendingCallbacks.push callback if callback
    setTimeout =>
      @flush()
    , 0

  specTrigger: (shouldResolve) ->
    unless @_specTrigger
      @_specTrigger = new Promise
      @_specTrigger.on => @flush()
    if (shouldResolve || @model.isOtPath @path, true) && !@_specTrigger.value
      @_specTrigger.resolve null, true
    return @_specTrigger

  # Sends ops to the server
  flush: ->
    # Used to flush the OT ops to the server when there are no pending STM transactions
    unless @_specTrigger
      shouldResolve = !isSpeculative @model._specModel()
      @specTrigger shouldResolve
      return

    # Only one inflight op at a time
    return if @inflightOp != null || @pendingOp == null

    @inflightOp = @pendingOp
    @pendingOp = null
    @inflightCallbacks = @pendingCallbacks
    @pendingCallbacks = []

    @model.socket.emit 'otOp', path: @path, op: @inflightOp, v: @version, (err, msg) =>
      @incomingSerializer.add [@inflightOp, false, err], msg.v if msg

  xf: (client, server) ->
    client_ = @type.transform client, server, 'left'
    server_ = @type.transform server, client, 'right'
    return [client_, server_]

Field.fromJSON = (json, model) ->
  field = new Field model, json.path, json.version
  field.snapshot = json.snapshot
  # TODO What to do with json.ops?
  return field
