transaction = require './transaction'
Model = require './Model'

# Update Model's prototype to provide server-side functionality
module.exports = (store, ioUri) ->

  Model::_commit = (txn) ->
    onTxn = @_onTxn
    removeTxn = @_removeTxn
    store._commit txn, (err, txn) ->
      return removeTxn transaction.id txn if err
      onTxn txn
  
  Model::_reqNewTxns = -> store._eachTxnSince @_adapter.ver + 1, @_onTxn

  Model::json = modelJson = (callback, self = this) ->
    return setTimeout modelJson, 10, callback, self if self._txnQueue.length
    callback JSON.stringify
      data: self.get()
      base: self._adapter.ver
      clientId: self._clientId
      txnCount: self._txnCount
      ioUri: ioUri
