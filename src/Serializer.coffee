# Given a stream of out of order messages and an index, Serializer
# figures out what messages to handle immediately and what messages
# to buffer and defer handling until later, if the incoming message
# has to wait first for another message.

DEFAULT_TIMEOUT = 1000

module.exports = Serializer = ({@withEach, onTimeout, timeout, init}) ->
  self = this
  if onTimeout
    timeout = DEFAULT_TIMEOUT if timeout is undefined
    self._setWaiter = ->
      return if @_waiter
      @_waiter = setTimeout ->
        onTimeout()
        self._clearWaiter()
      , timeout
    self._clearWaiter = ->
      if @_waiter
        clearTimeout @_waiter
        @_waiter = null

  self._pending = {}
  self._index = init ? 1  # Corresponds to ver in Store and txnNum in Model
  return

Serializer::=
  _clearWaiter: ->
  _setWaiter: ->
  add: (txn, txnIndex, arg) ->
    index = @_index
    # Cache this message to be applied later if it is not the next index
    if txnIndex > index
      @_pending[txnIndex] = txn
      @_setWaiter()
      return true

    # Ignore this message if it is older than the current index
    return false if txnIndex < index

    # Otherwise apply it immediately
    @withEach txn, index, arg
    @_clearWaiter()

    # And apply any messages that were waiting for txn
    index++
    pending = @_pending
    while txn = pending[index]
      @withEach txn, index, arg
      delete pending[index++]
    @_index = index
    return true

  setIndex: (@_index) ->

  clearPending: ->
    index = @_index
    pending = @_pending
    for i of pending
      delete pending[i] if i < index
