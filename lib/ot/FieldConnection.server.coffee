FieldConnection = module.exports = (@field, @socket) ->
  @listener = null
  @queue = []
  @busy = false

FieldConnection:: =
  selfDestruct: ->
    delete @field.connections[@socket.id]

  # Handles serial execution of queue of messages that have accumulated
  # from incoming socket.io ot messages
  flush: ->
    return if @busy || !@queue.length

    @busy = true

    [query, socketioCallback] = @queue.shift()

    callback = =>
      @busy = false
      @flush()

    # TODO Close docs?
    if query.op
      @otApply query, callback, socketioCallback

  otApply: ({op, v}, callback, socketioCallback) ->
    opData = {op, v}
    opData.meta ||= {}
    opData.meta.src = @socket.id
    field = @field
    field.applyOp opData, (err, appliedVer) ->
      if err
        socketioCallback err.message
      else
        socketioCallback null,
          path: field.path, v: appliedVer
      callback()

  # ver = null if we want to listen since HEAD
  listenSinceVer: (ver) ->
    unless ver == null
      ops = @field.getOps ver
      for op in ops
        # TODO Compose ops into a single op?
        @socket.emit 'otOp', op
