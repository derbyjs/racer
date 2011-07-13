Model = require './Model'

# Update Model's prototype to provide server-side functionality
module.exports = (store, ioUri) ->

  Model::_send = (txn) ->
    onTxn = @_onTxn
    removeTxn = @_removeTxn
    store._commit txn, null, (err, txn) ->
      return removeTxn transaction.id txn if err
      onTxn txn
    return true
  
  Model::_reqNewTxns = -> store._txnsSince @_base + 1, @_onTxn

  Model::json = modelJson = (callback, self = this) ->
    return setTimeout modelJson, 10, callback, self if self._txnQueue.length
    callback JSON.stringify
      data: self._data
      base: self._base
      clientId: self._clientId
      txnCount: self._txnCount
      ioUri: ioUri