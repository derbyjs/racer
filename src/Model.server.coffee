transaction = require './transaction'
BrowserModel = require './Model'
Promise = require './Promise'

module.exports = ServerModel = ->
  self = this
  BrowserModel.apply self, arguments
  self._onLoad = []
  self.clientIdPromise = (new Promise).on (clientId) ->
    self._clientId = clientId
  return

ServerModel:: = Object.create BrowserModel::

# Update Model's prototype to provide server-side functionality
# TODO: This file contains STM-specific code. This should be moved to the STM mixin

ServerModel::_commit = (txn) ->
  return if txn.isPrivate
  self = this
  @store._commit txn, (err, txn) ->
    return self._removeTxn transaction.id txn if err
    self._onTxn txn

ServerModel::bundle = (callback) ->
  self = this
  # Get the speculative model, which will apply any pending private path
  # transactions that may get stuck in the first position of the queue
  @_specModel()
  # Wait for all pending transactions to complete before returning
  return setTimeout (-> self.bundle callback), 10  if @_txnQueue.length
  Promise.parallel([@clientIdPromise, @startIdPromise]).on ->
    self._bundle callback

ServerModel::_bundle = (callback) ->
  @emit 'bundle'
  # Unsubscribe the model from PubSub events. It will be resubscribed again
  # when the model connects over socket.io
  clientId = @_clientId
  @store._pubSub.unsubscribe clientId
  delete @store._localModels[clientId]

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

ServerModel::_addSub = (paths, callback) ->
  store = @store
  self = this
  @clientIdPromise.on (clientId) ->
    # Subscribe while the model still only resides on the server
    # The model is unsubscribed before sending to the browser
    store._pubSub.subscribe clientId, paths
    store._localModels[clientId] = self

    store._fetchSubData paths, (err, data, otData) ->
      # TODO: This is a quick fix to make sure that subscribed items
      # get copied on the server. Implement something that does this
      # just for the memory store instead of doing it here
      self._initSubData JSON.parse JSON.stringify data
      self._initSubOtData otData
      callback()
