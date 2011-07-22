redis = require 'redis'
MemoryAdapter = require './adapters/Memory'
Model = require './Model'
Stm = require './Stm'
PubSub = require './PubSub'
transaction = require './transaction'

PENDING_INTERVAL = 500

Store = module.exports = (AdapterClass = MemoryAdapter) ->
  @_adapter = adapter = new AdapterClass
  @_redisClient = redisClient = redis.createClient()
  stm = new Stm redisClient

  # If I recall correctly from Redis doc, Redis clients used for
  # pubsub should only be used for pubsub, so we don't pass
  # @_redisClient to new PubSub
  @_pubsub = pubsub = new PubSub('Redis')
  pubsub.onMessage = (clientId, txn) ->
    socketForModel(clientId).emit 'txn', txn

  # socketForModel(clientId) is a getter
  # socketForModel(clientId, socket) is a setter
  socketForModel = (clientId, socket) ->
    sockets._byClientId ||= {}
    if socket
      socket.clientId = clientId
      socket.unregister = ->
        delete sockets._byClientId[clientId]
      dummySocket = sockets._byClientId[clientId]
      sockets._byClientId[clientId] = socket
      if dummySocket
        socket.emit args... for args in dummySocket._buffer
    
    sockets._byClientId[clientId] ||= dummySocket =
        _buffer: []
        emit: ->
          @_buffer.push arguments
        unregister: ->
          @_buffer = []
          delete sockets._byClientId[clientId]
  
  @_nextClientId = nextClientId = (callback) ->
    redisClient.incr 'clientIdCount', (err, value) ->
      throw err if err
      callback value.toString(36)
  
  # TODO: DRY this with Model
  clientId = ''
  nextClientId (err, value) ->
    clientId = value
  txnCount = 0
  nextTxnId = -> clientId + '.' + txnCount++
  
  sockets = null
  @_setSockets = (s) ->
    sockets = s
    sockets.on 'connection', (socket) ->
      socket.on 'clientId', (clientId) ->
        # TODO Once socket.io supports query params in the
        # socket.io urls, then we can remove this. Instead,
        # we can add the socket <-> clientId assoc in the
        # `sockets.on 'connection'...` callback.
        socketForModel(clientId, socket)
        # TODO Map the clientId to a nickname (e.g., via session?), and broadcast presence
        #      to subscribers of the relevant namespace(s)
      socket.on 'disconnect', ->
        pubsub.unsubscribe socket.clientId
        socket.unregister()
      socket.on 'txn', (txn) ->
        commit txn, null, (err, txn) ->
          if err && err.code == 'STM_CONFLICT'
            socket.emit 'txnFail', transaction.id txn
      socket.on 'txnsSince', (ver) ->
        eachTxnSince ver, (txn) ->
          socket.emit 'txn', txn
  
  # TODO: This algorithm will need to change when we go multi-process,
  # because we can't count on the version to increase sequentially
  pending = {}
  verToWrite = 1
  @_pendingInterval = setInterval ->
    while txn = pending[verToWrite]
      args = transaction.args txn
      args.push verToWrite, (err) ->
        # TODO: Better adapter error handling and potentially a second callback
        # to the caller of _commit when the adapter operation completes
        throw err if err
      adapter[transaction.method txn].apply adapter, args
      delete pending[verToWrite++]
  , PENDING_INTERVAL
  
  @_commit = commit = (txn, callback) ->
    stm.commit txn, (err, ver) ->
      txn[0] = ver
      callback err, txn if callback
      return if err
      # TODO Wrap PubSub with TxnPubSub. Then, just pass around txn,
      # and TxnPubSub can subtract out the payload of path from txn, too.
      pubsub.publish transaction.clientId(txn), transaction.path(txn), txn
      pending[ver] = txn
  
  # TODO Modify this to deal with subsets of data. Currently fetches all transactions since globally
  @_eachTxnSince = eachTxnSince = (ver, onTxn, done) ->
    redisClient.zrangebyscore 'txns', ver, '+inf', 'withscores', (err, vals) ->
      throw err if err
      txn = null
      for val, i in vals
        if i % 2
          txn[0] = +val
          onTxn txn
        else
          txn = JSON.parse val
      done() if done
  
  subscribeModel = (model, paths) ->
    pubsub.subscribe model._clientId, paths...
  populateModel = (model, paths, callback) ->
    modelAdapter = model._adapter
    maxVer = 0
    getting = paths.length
    for path in paths
      # TODO: Select only the correct properties instead of everything under the path
      path = path.replace /\.\*$/, ''
      adapter.get path, (err, value, ver) ->
        return callback err if err
        maxVer = Math.max maxVer, ver
        modelAdapter.set path, value, ver
        return if --getting
        # Apply any transactions in the STM that have not yet been applied
        # to the store
        eachTxnSince maxVer + 1, onTxn = (txn) ->
          method = transaction.method txn
          args = transaction.args txn
          args.push transaction.base txn
          modelAdapter[method].apply modelAdapter, args
        , done = -> callback null, model
  
  @subscribe = (model, paths..., callback) ->
    # TODO: Support path wildcards, references, and functions
    # If subscribe(callback)
    if model && !paths.length && !callback
      callback = model
      model = null

    if model
      # If subscribe(model, paths..., callback)
      if model instanceof Model
        subscribeModel model, paths
        return populateModel model, paths, callback

      # If subscribe(paths..., callback)
      paths.unshift model

    nextClientId (clientId) ->
      newModel = new Model clientId
      subscribeModel newModel, paths
      populateModel newModel, paths, callback
  
  @unsubscribe = ->
    pubsub.unsubscribe socket.clientId
  
  @flush = (callback) ->
    done = false
    cb = (err) ->
      if callback && (done || err)
        callback err
        callback = null
      done = true
    adapter.flush cb
    redisClient.flushdb cb
  
  @get = -> adapter.get arguments...
  
  @set = (path, value, ver = null, callback) ->
    if 'function' == typeof ver
      # Just in case of @set(path, value, callback)
      throw new Error 'You must pass null or a version number to set'
    @_commit [ver, nextTxnId(), 'set', path, value], callback
  
  @del = (path, ver = null, callback) ->
    @_commit [ver, nextTxnId(), 'del', path], callback
  
  return
