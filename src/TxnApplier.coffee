transaction = require './transaction'

# Given a stream of out of order transactions and an index, TxnApplier
# figures out what to apply immediately and what to buffer
# to apply later if the incoming transaction has to wait first for
# another transaction.

DEFAULT_TIMEOUT = 500

module.exports = TxnApplier = ({@applyTxn, onTimeout, timeout}) ->
  self = this
  if onTimeout
    timeout = DEFAULT_TIMEOUT if timeout is undefined
    self._setWaiter = ->
      return if @_waiter
      @_waiter = setTimeout ->
        onTimeout()
        self._clearWaiter()
      , timeout
    self._clearWaiter: ->
      if @_waiter
        clearTimeout @_waiter
        @_waiter = null
  
  self._pending = {}
  self._index = 1  # Corresponds to ver in Store and txnNum in Model
  return

TxnApplier::=
  self._setWaiter = ->
  self._clearWaiter = ->
  add: (txn, txnIndex) ->
    index = @_index
    # Cache this transaction to be applied later if it is not the next index
    if txnIndex > index
      @_pending[txnIndex] = txn
      @_setWaiter()
      return true
    # Ignore this transaction if it is older than the current index
    return false if txnIndex < index
    # Otherwise apply it immediately
    @applyTxn txn, index
    @_clearWaiter()
    # And apply any transactions that were waiting for txn
    index++
    pending = @_pending
    while txn = pending[index]
      @applyTxn txn, index
      delete pending[index++]
    @_index = index
    return true
  setIndex: (@_index) ->
  clearPending: ->
    index = @_index
    pending = @_pending
    for i of pending
      delete pending[i] if i < index
