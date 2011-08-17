transaction = require './transaction'
module.exports = Model = require './Model'

# Update Model's prototype to provide server-side functionality
Model::setStore = (@store) ->

Model::setIoUri = (@ioUri) ->

Model::_browserOnTxn = Model::_onTxn
Model::_onTxn = (txn) ->
  self = this
  @store._nextTxnNum self._clientId, (num) ->
    self._txnNum = num
    self._browserOnTxn txn, num

Model::_commit = (txn) ->
  self = this
  @store._commit txn, (err, txn) ->
    return self._removeTxn transaction.id txn if err
    self._onTxn txn

Model::bundle = bundle = (callback, self = this) ->
  # Wait for all pending transactions to complete before returning
  return setTimeout ->
    self.bundle(callback, self)
  , 10 if self._txnQueue.length
  
  # Unsubscribe the model from PubSub events. It will be resubscribed again
  # when the model connects over socket.io
  clientId = self._clientId
  @store._pubSub.unsubscribe clientId
  delete @store._localModels[clientId]
  
  callback JSON.stringify
    data: self.get()
    base: self._adapter.ver
    clientId: clientId
    storeSubs: self._storeSubs
    startId: self._startId
    txnCount: self._txnCount
    txnNum: self._txnNum
    ioUri: @ioUri
