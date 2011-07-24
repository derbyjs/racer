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
  # Redis clients used for pub/sub should only be used for pub/sub,
  # so we don't pass @_redisClient to new PubSub
  @_pubSub = pubSub = new PubSub
  
  @_setSockets = (sockets) ->
    sockets.on 'connection', (socket) ->
      socket.on 'clientId', (clientId) ->
        # TODO Once socket.io supports query params in the
        # socket.io urls, then we can remove this. Instead,
        # we can add the socket <-> clientId assoc in the
        # `sockets.on 'connection'...` callback.
        socketForModel clientId, socket
        # TODO Map the clientId to a nickname (e.g., via session?), and broadcast presence
        #      to subscribers of the relevant namespace(s)
      socket.on 'disconnect', ->
        pubSub.unsubscribe socket.clientId if socket.clientId
        socket.unregister() if socket.unregister
      socket.on 'txn', (txn) ->
        commit txn, (err, txn) ->
          socket.emit 'txnErr', err, transaction.id txn if err
      socket.on 'txnsSince', (ver) ->
        eachTxnSince ver, (txn) ->
          socket.emit 'txn', txn
    
    pubSub.onMessage = (clientId, txn) ->
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
  
  # TODO Modify this to deal with subsets of data. Currently fetches all transactions since globally
  @_eachTxnSince = eachTxnSince = (ver, onTxn) ->
    redisClient.zrangebyscore 'txns', ver, '+inf', 'withscores', (err, vals) ->
      throw err if err
      txn = null
      for val, i in vals
        if i % 2
          txn[0] = +val
          onTxn txn
        else
          txn = JSON.parse val
  
  subscribeModel = (model, paths) ->
    pubSub.subscribe model._clientId, paths...
  populateModel = (model, paths, callback) ->
    subscribeModel model, paths
    modelAdapter = model._adapter
    getting = paths.length
    for path in paths
      # TODO: Select only the correct properties instead of everything under the path
      path = path.replace /\.\*$/, ''
      adapter.get path, (err, value, ver) ->
        return callback err if err
        modelAdapter.set path, value, ver
        return if --getting
        callback null, model
  
  @subscribe = (model, paths..., callback) ->
    # TODO: Support path wildcards, references, and functions
    
    if arguments.length == 1
      # If subscribe(callback)
      callback = model
    else
      # If subscribe(model, paths..., callback)
      return populateModel model, paths, callback if model instanceof Model
      # If subscribe(paths..., callback)
      paths.unshift model
    
    nextClientId (clientId) ->
      populateModel new Model(clientId), paths, callback
  
  @unsubscribe = ->
    # TODO: Debug: Pretty sure socket is undefined here
    pubSub.unsubscribe socket.clientId
  
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
  
  @set = (path, value, ver, callback) ->
    commit [ver, nextTxnId(), 'set', path, value], callback
  @del = (path, ver, callback) ->
    commit [ver, nextTxnId(), 'del', path], callback
  
  nextClientId = (callback) ->
    redisClient.incr 'clientIdCount', (err, value) ->
      throw err if err
      callback value.toString(36)
  # Note that Store clientIds MUST begin with '$', as this is used to treat
  # conflict detection between Store and Model transactions differently
  clientId = ''
  nextClientId (value) -> clientId = '$' + value
  txnCount = 0
  nextTxnId = -> clientId + '.' + txnCount++
  
  @_commit = commit = (txn, callback) ->
    ver = transaction.base txn
    if ver && typeof ver != 'number'
      # In case of something like @set(path, value, callback)
      throw new Error 'Version must be null or a number'
    stm.commit txn, (err, ver) ->
      txn[0] = ver
      callback err, txn if callback
      return if err
      # TODO Wrap PubSub with TxnPubSub. Then, just pass around txn,
      # and TxnPubSub can subtract out the payload of path from txn, too.
      pubSub.publish transaction.clientId(txn), transaction.path(txn), txn
      pending[ver] = txn
  
  # TODO: This algorithm will need to change when we go multi-process,
  # because we can't count on the version to increase sequentially
  pending = {}
  verToWrite = 1
  @_pendingInterval = setInterval ->
    while txn = pending[verToWrite]
      args = transaction.args txn
      args.push verToWrite, (err) ->
        # TODO: Better adapter error handling and potentially a second callback
        # to the caller of commit when the adapter operation completes
        throw err if err
      adapter[transaction.method txn].apply adapter, args
      delete pending[verToWrite++]
  , PENDING_INTERVAL
  
  return
