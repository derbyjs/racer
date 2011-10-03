transaction = require './transaction'
BrowserModel = require './Model'

module.exports = ServerModel = ->
  BrowserModel.apply @, arguments

ServerModel:: = Object.create BrowserModel::

# Update Model's prototype to provide server-side functionality

ServerModel::_waitForClientId = (callback) ->
  (@_pendingClientId || @_pendingClientId = []).push callback
ServerModel::_setClientId = (@_clientId) ->
  @_waitForClientId = (callback) -> callback()
  callback() for callback in @_pendingClientId  if @_pendingClientId
  return

ServerModel::_baseOnTxn = ServerModel::_onTxn
ServerModel::_onTxn = (txn) ->
  self = this
  @_waitForClientId ->
    self.store._nextTxnNum self._clientId, (num) ->
      self._txnNum = num
      self._baseOnTxn txn, num

ServerModel::_commit = (txn) ->
  self = this
  @store._commit txn, (err, txn) ->
    return self._removeTxn transaction.id txn if err
    self._onTxn txn

ServerModel::bundle = (callback) ->
  self = this
  # Wait for all pending transactions to complete before returning
  return setTimeout (-> self.bundle callback), 10  if @_txnQueue.length
  @_waitForClientId -> self._bundle callback

ServerModel::_bundle = (callback) ->
  # Unsubscribe the model from PubSub events. It will be resubscribed again
  # when the model connects over socket.io
  clientId = @_clientId
  @store._pubSub.unsubscribe clientId
  delete @store._localModels[clientId]
  
  callback JSON.stringify
    data: @get()
    base: @_adapter.ver
    clientId: clientId
    storeSubs: @_storeSubs
    startId: @_startId
    txnCount: @_txnCount
    txnNum: @_txnNum
    ioUri: @_ioUri

ServerModel::connected = true
ServerModel::canConnect = true

ServerModel::_addSub = (paths, callback) ->
  store = @store
  self = this
  @_waitForClientId ->
    # Subscribe while the model still only resides on the server
    # The model is unsubscribed before sending to the browser
    clientId = self.clientId
    store._pubSub.subscribe clientId, paths
    store._localModels[clientId] = self

    store._subData paths, (err, data) ->
      self._initSubData data
      callback()
