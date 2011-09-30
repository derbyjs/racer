FieldConnection = module.exports = ->
  @listener = null
  @queue = []
  @busy = false

FieldConnection:: =
  # Handles serial execution of queue of messages that have accumulated
  # from incoming socket.io ot messages
  flush: ->
    return if @busy || !@queue.length

    @busy = true

    query = @queue.shift()

    callback = =>
      @busy = false
      @flush()


    # TODO Close docs?
    if query.op
      @otApply query, callback
