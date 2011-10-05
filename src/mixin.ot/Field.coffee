text = require 'share/lib/types/text'
specHelper = require '../specHelper'
Promise = require '../Promise'

Field = module.exports = (model, @path, @version = 0, @type = text) ->
  # @type.apply(snapshot, op)
  # @type.transform(op1, op2, side)
  # @type.normalize(op)
  # @type.create() -> ''

  @model = model
  @snapshot = null
  @queue = []
  @pendingOp = null
  @pendingCallbacks = []
  @inflightOp = null
  @inflightCallbacks = []
  @serverOps = {}

  self = this
  model._on 'change', ([path, op, oldSnapshot], isRemote) ->
    return unless path == self.path
    for {p, i, d} in op
      if i
        model.emit 'insertOT', [path, i, p], !isRemote
      else
        model.emit 'delOT', [path, d, p], !isRemote
    return

  return

Field:: =
  onRemoteOp: (op, v) ->
    return if v < @version
    throw new Error "Expected version #{@version} but got #{v}" unless v == @version
    docOp = @serverOps[@version] = op
    if @inflightOp
      [@inflightOp, docOp] = @xf @inflightOp, docOp
    if @pendingOp
      [@pendingOp, docOp] = @xf @pendingOp, docOp

    @version++
    @otApply docOp, true

  otApply: (docOp, isRemote) ->
    oldSnapshot = @snapshot
    @snapshot = @type.apply oldSnapshot, docOp
    @model.emit 'change', [@path, docOp, oldSnapshot], isRemote
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

  specTrigger: (shouldFulfill) ->
    unless @_specTrigger
      @_specTrigger = new Promise
      @_specTrigger.on => @flush()
    @_specTrigger.fulfill true if shouldFulfill && !@_specTrigger.value
    return @_specTrigger

  # Sends ops to the server
  flush: ->
    # Used to flush the OT ops to the server when the OT flag on
    # the path transforms from speculative to permanent.
    unless @_specTrigger
      shouldFulfill = specHelper.isSpeculative @model._adapter.get(@path, @model._specModel()[0])
      @specTrigger shouldFulfill
      return

    # Only one inflight op at a time
    return if @inflightOp != null || @pendingOp == null

    @inflightOp = @pendingOp
    @pendingOp = null
    @inflightCallbacks = @pendingCallbacks
    @pendingCallbacks = []

    # @model.socket.send msg, (err, res) ->
    @model.socket.emit 'otOp', path: @path, op: @inflightOp, v: @version, (err, msg) =>
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
        @otApply undo, true
        callback err for callback in @inflightCallbacks
        return @flush

      ver = msg.v if msg
      unless ver == @version
        throw new Error 'Invalid version from server'

      @serverOps[@version] = oldInflightOp
      @version++
      callback null, oldInflightOp for callback in @inflightCallbacks
      @flush()

  xf: (client, server) ->
    client_ = @type.transform client, server, 'left'
    server_ = @type.transform server, client, 'right'
    return [client_, server_]
