transaction = require './transaction'
BrowserModel = require './Model'
Promise = require './Promise'

module.exports = ServerModel = ->
  BrowserModel.apply @, arguments
  @clientIdPromise = new Promise()
  return

ServerModel:: = Object.create BrowserModel::

# Update Model's prototype to provide server-side functionality

ServerModel::_baseOnTxn = ServerModel::_onTxn
ServerModel::_onTxn = (txn) ->
  self = this
  @clientIdPromise.on (clientId) ->
    self.store._nextTxnNum clientId, (num) ->
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
  Promise.parallel(@clientIdPromise, @startIdPromise).on -> self._bundle callback

ServerModel::_bundle = (callback) ->
  # Unsubscribe the model from PubSub events. It will be resubscribed again
  # when the model connects over socket.io
  clientId = @clientId
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
  @clientIdPromise.on (clientId) ->
    self.clientId = clientId
    # Subscribe while the model still only resides on the server
    # The model is unsubscribed before sending to the browser
    store._pubSub.subscribe clientId, paths
    store._localModels[clientId] = self

    store._subData paths, (err, data) ->
      self._initSubData data
      callback()
