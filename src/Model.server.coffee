transaction = require './transaction'
BrowserModel = require './Model'
Promise = require './Promise'

module.exports = ServerModel = ->
  self = this
  BrowserModel.apply self, arguments
  self._onLoad = []
  self.clientIdPromise = (new Promise).on (clientId) ->
    self._clientId = clientId

  # allTxnsApplied helps us to wait for the txn queue to become empty
  # before bundling the model via ServerModel::bundle
  self.__applyTxn__= self._applyTxn
  self._applyTxn = (txnId) ->
    @__applyTxn__ txnId
    if @_txnQueue.length == 0
      @emit 'allTxnsApplied'
  self.liveQueries = {}
  return

ServerModel:: = Object.create BrowserModel::

# Update Model's prototype to provide server-side functionality
# TODO: This file contains STM-specific code. This should be moved to the STM mixin

ServerModel::_commit = (txn) ->
  return if txn.isPrivate
  self = this
  @store.commit txn, (err, txn) ->
    return self._removeTxn transaction.id txn if err
    self._onTxn txn
    self._specModel() # For flushing private path txns from the txnQueue

ServerModel::bundle = (callback) ->
  self = this
  # Get the speculative model, which will apply any pending private path
  # transactions that may get stuck in the first position of the queue
  @_specModel()
  # Wait for all pending transactions to complete before returning
  if @_txnQueue.length
    return @_once 'allTxnsApplied', -> self.bundle callback
  Promise.parallel([@clientIdPromise, @startIdPromise]).on ->
    self._bundle callback

ServerModel::_bundle = (callback) ->
  @emit 'bundle'
  # Unsubscribe the model from PubSub events. It will be resubscribed again
  # when the model connects over socket.io
  clientId = @_clientId
  @store.unsubscribe clientId
  @store.unregisterLocalModel @

  otFields = {}
  for path, field of @otFields
    # OT objects aren't serializable until after one or more OT operations
    # have occured on that object
    otFields[path] = field.toJSON()  if field.toJSON

  callback JSON.stringify
    data: @get()
    base: @_adapter.version
    otFields: otFields
    onLoad: @_onLoad
    clientId: clientId
    storeSubs: @_storeSubs
    startId: @_startId
    count: @_count
    ioUri: @_ioUri
    liveQueries: @liveQueries

ServerModel::_addSub = (channels, callback) ->
  model = this
  store = model.store
  @clientIdPromise.on (clientId) ->
    store.registerLocalModel model
    # Subscribe while the model still only resides on the server
    # The model is unsubscribed before sending to the browser
    store.subscribe model._clientId, channels, (err, data, otData) ->
      # TODO: This is a quick fix to make sure that subscribed items
      # get copied on the server. Implement something that does this
      # just for the memory store instead of doing it here
      model._initSubData data
      model._initSubOtData otData
      for chan in channels
        if chan.isQuery
          model.liveQueries[chan.hash()] = chan.serialize()
      callback()
