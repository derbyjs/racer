transaction = require './transaction'
pathParser = require './pathParser.server'
specHelper = require './specHelper'
module.exports = Model = require './Model'

# Update Model's prototype to provide server-side functionality

Model::_waitForClientId = (callback) ->
  (@_pendingClientId || @_pendingClientId = []).push callback
Model::_setClientId = (@_clientId) ->
  @_waitForClientId = (callback) -> callback()
  callback() for callback in @_pendingClientId  if @_pendingClientId
  return

Model::_browserOnTxn = Model::_onTxn
Model::_onTxn = (txn) ->
  self = this
  @_waitForClientId ->
    self.store._nextTxnNum self._clientId, (num) ->
      self._txnNum = num
      self._browserOnTxn txn, num

Model::_commit = (txn) ->
  self = this
  @store._commit txn, (err, txn) ->
    return self._removeTxn transaction.id txn if err
    self._onTxn txn

Model::bundle = (callback) ->
  self = this
  # Wait for all pending transactions to complete before returning
  return setTimeout (-> self.bundle callback), 10  if @_txnQueue.length
  @_waitForClientId -> self._bundle callback

Model::_bundle = (callback) ->
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

Model::connected = true
Model::canConnect = true


setModelValue = (modelAdapter, root, remainder, value, ver) ->
  # Set only the specified property if there is no remainder
  unless remainder
    value =
      if typeof value is 'object'
        if specHelper.isArray value then [] else {}
      else value
    return modelAdapter.set root, value, ver
  # If the remainder is a trailing **, set everything below the root
  return modelAdapter.set root, value, ver if remainder == '**'
  # If the remainder starts with *. or is *, set each property one level down
  if remainder.charAt(0) == '*' && (c = remainder.charAt(1)) == '.' || c == ''
    [appendRoot, remainder] = pathParser.splitPattern remainder.substr 2
    for prop of value
      nextRoot = if root then root + '.' + prop else prop
      nextValue = value[prop]
      if appendRoot
        nextRoot += '.' + appendRoot
        nextValue = pathParser.fastLookup appendRoot, nextValue
      setModelValue modelAdapter, nextRoot, remainder, nextValue, ver
  # TODO: Support ** not at the end of a path
  # TODO: Support (a|b) syntax

Model::subscribe = (paths..., callback) ->
  self = this
  @_waitForClientId -> self._subscribe paths, callback

Model::_subscribe = (paths, callback) ->
  # TODO: Support path wildcards, references, and functions

  _paths = []
  for path in paths
    if typeof path is 'object'
      for key, value of path
        root = pathParser.splitPattern(value)[0]
        @set key, @ref root
        _paths.push value
      continue
    _paths.push path
  
  # Store subscriptions in the model so that it can submit them to the
  # server when it connects
  @_storeSubs = @_storeSubs.concat _paths
  # Subscribe while the model still only resides on the server
  # The model is unsubscribed before sending to the browser
  clientId = @_clientId
  store = @store
  store._pubSub.subscribe clientId, _paths
  store._localModels[clientId] = this
  
  maxVer = 0
  getting = _paths.length
  storeAdapter = store._adapter
  modelAdapter = @_adapter
  for path in _paths
    [root, remainder] = pathParser.splitPattern path
    storeAdapter.get root, (err, value, ver) ->
      if err
        callback err if callback
        return callback = null
      maxVer = Math.max maxVer, ver
      setModelValue modelAdapter, root, remainder, value, ver
      return if --getting
      modelAdapter.ver = maxVer
      
      # Apply any transactions in the STM that have not yet been applied
      # to the store
      store._forTxnSince maxVer + 1, clientId, onTxn = (txn) ->
        method = transaction.method txn
        args = transaction.args(txn).slice 0
        args.push transaction.base txn
        modelAdapter[method] args...
      , callback || ->
  
Model::unsubscribe = (paths..., callback) ->
  throw new Error 'Unimplemented'
