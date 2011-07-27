transaction = require './transaction'

# Given a stream of out of order transactions and an index, TxnApplier
# figures out what to apply immediately and what to buffer
# to apply later if the incoming transaction has to wait first for
# another transaction.

module.exports = TxnApplier = ({waiter, delay, @applyTxn, onTimeout}) ->
  self = this
  delay = 500 if delay is undefined
  if waiter is 'timeout'
    self._timeout = true
    self._clearWaiter = clearTimeout
    self._setWaiter = ->
      setTimeout ->
        onTimeout() if onTimeout
        self.clearWaiter()
      , delay
  else
    self._clearWaiter = clearInterval
    self._setWaiter = ->
      setInterval ->
        self.flushValidPending()
      , delay
  self._pending = {}
  self._index = 1  # Corresponds to ver in Store and txnNum in Model
  return

TxnApplier::=
  add: (txn, index) ->
    _index = @_index
    # Cache this transaction to be applied later if it is not the next index
    if index > _index
      @_pending[index] = txn
      @_waiter ||= @_setWaiter()
      return true
    # Ignore this transaction if it is older than the current index
    return false if index < _index
    # Otherwise apply it immediately
    @applyTxn txn, index
    @clearWaiter() if @_timeout
    # And apply any transactions that were waiting for txn
    @_index++
    @flushValidPending()
    return true
  flushValidPending: ->
    pending = @_pending
    index = @_index
    while txn = pending[index]
      @applyTxn txn, index
      delete pending[index++]
    @_index = index
  setIndex: (@_index) ->
  clearPending: ->
    index = @_index
    pending = @_pending
    for i of pending
      delete pending[i] if i < index
  clearWaiter: ->
    if @_waiter
      @_clearWaiter @_waiter
      @_waiter = null
