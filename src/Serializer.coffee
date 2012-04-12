# Given a stream of out of order messages and an index, Serializer
# figures out what messages to handle immediately and what messages
# to buffer and defer handling until later, if the incoming message
# has to wait first for another message.

DEFAULT_EXPIRY = 1000

# TODO Respect Single Responsibility -- place waiter code elsewhere
module.exports = Serializer = ({@withEach, @onTimeout, @expiry, init}) ->
  if @onTimeout
    @expiry ?= DEFAULT_EXPIRY

  # Maps future indexes -> messages
  @_pending = {}

  # Corresponds to ver in Store and txnNum in Model
  @_index = init ? 1

  return

Serializer::=
  _setWaiter: ->
    return if !@onTimeout || @_waiter
    @_waiter = setTimeout =>
      @onTimeout()
      @_clearWaiter()
    , @expiry

  _clearWaiter: ->
    return unless @onTimeout
    if @_waiter
      clearTimeout @_waiter
      delete @_waiter

  add: (msg, msgIndex, arg) ->
    # Cache this message to be applied later if it is not the next index
    if msgIndex > @_index
      @_pending[msgIndex] = msg
      @_setWaiter()
      return true

    # Ignore this message if it is older than the current index
    return false if msgIndex < @_index

    # Otherwise apply it immediately
    @withEach msg, @_index++, arg
    @_clearWaiter()

    # And apply any messages that were waiting for txn
    pending = @_pending
    while msg = pending[@_index]
      @withEach msg, @_index, arg
      delete pending[@_index++]
    return true

  setIndex: (@_index) ->

  clearPending: ->
    index = @_index
    pending = @_pending
    for i of pending
      delete pending[i] if i < index
