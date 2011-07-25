transaction = require './transaction'
Model = require './Model'

# Update Model's prototype to provide server-side functionality
module.exports = (store, ioUri) ->

  Model::_commit = (txn) ->
    self = this
    store._commit txn, (err, txn) ->
      return self._removeTxn transaction.id txn if err
      store._nextTxnNum self._clientId, (num) ->
        self._onTxn txn, num

  Model::json = modelJson = (callback, self = this) ->
    return setTimeout modelJson, 10, callback, self if self._txnQueue.length
    callback JSON.stringify
      data: self.get()
      base: self._adapter.ver
      clientId: self._clientId
      txnCount: self._txnCount
      ioUri: ioUri
