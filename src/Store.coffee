redis = require 'redis'
MemoryAdapter = require './adapters/Memory'
Model = require './Model'
Stm = require './Stm'
PubSub = require './PubSub'
transaction = require './transaction'
pathParser = require './pathParser.server'

PENDING_INTERVAL = 500

Store = module.exports = (AdapterClass = MemoryAdapter) ->
  @_adapter = adapter = new AdapterClass
  @_redisClient = redisClient = redis.createClient()
  stm = new Stm redisClient
  
  # Redis clients used for subscribe, psubscribe, unsubscribe,
  # and punsubscribe cannot be used with any other commands.
  # Therefore, we can only pass the current `redisClient` as the
  # pubsub's @_publishClient.
  @_pubSub = pubSub = new PubSub
  pubSub.onMessage = (clientId, txn) ->
    publisherId = transaction.clientId txn
    return if clientId == publisherId
    if socket = clientSockets[clientId]
      nextTxnNum clientId, (num) ->
        socket.emit 'txn', txn, num
  
  @_nextTxnNum = nextTxnNum = (clientId, callback) ->
    redisClient.incr 'txnClock.' + clientId, (err, value) ->
      throw err if err
      callback value
  
  clientSockets = {}
  clientSubs = {}
  @_setSockets = (sockets) ->
    sockets.on 'connection', (socket) ->
      socket.on 'sub', (clientId, paths) ->
        # TODO Once socket.io supports query params in the
        # socket.io urls, then we can remove this. Instead,
        # we can add the socket <-> clientId assoc in the
        # `sockets.on 'connection'...` callback.
        # TODO Map the clientId to a nickname (e.g., via session?), and broadcast presence
        #      to subscribers of the relevant namespace(s)
        clientSockets[clientId] = socket
        clientSubs[clientId] = (pathParser.globToRegExp path for path in paths)
        pubSub.subscribe clientId, paths...
        
        socket.on 'disconnect', ->
          pubSub.unsubscribe clientId
          delete clientSockets[clientId]
          delete clientSubs[clientId]
          redisClient.del 'txnClock.' + clientId, (err, value) ->
            throw err if err
        socket.on 'txn', (txn) ->
          commit txn, (err, txn) ->
            return socket.emit 'txnErr', err, transaction.id(txn) if err
            nextTxnNum clientId, (num) ->
              socket.emit 'txnOk', transaction.base(txn), transaction.id(txn), num
        socket.on 'txnsSince', (ver) ->
          # Reset the pending transaction number in the model
          redisClient.get 'txnClock.' + clientId, (err, value) ->
            throw err if err
            socket.emit 'txnNum', value || 0
            eachTxnSince ver, clientId, (txn) ->
              nextTxnNum clientId, (num) ->
                socket.emit 'txn', txn, num
  
  @_eachTxnSince = eachTxnSince = (ver, clientId, onTxn) ->
    return unless subs = clientSubs[clientId]
    subscribed = transaction.subscribed
    
    # TODO Replace with a LUA script that does filtering?
    redisClient.zrangebyscore 'txns', ver, '+inf', 'withscores', (err, vals) ->
      throw err if err
      txn = null
      for val, i in vals
        if i % 2
          continue unless subscribed txn, subs
          txn[0] = +val
          onTxn txn
        else
          txn = JSON.parse val
  
  populateModel = (model, paths, callback) ->
    modelAdapter = model._adapter
    subs = modelAdapter.get('$subs') || []
    modelAdapter.set '$subs', subs.concat paths
    
    getting = paths.length
    for path in paths
      # TODO: Select only the correct properties instead of everything under the path
      path = path.replace /\.\*.*/, ''
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
    throw new Error 'Unimplemented'
  
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
    redisClient.incr 'clientClock', (err, value) ->
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
  
  ## Ensure Serialization of Transactions to the DB ##
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
      adapter[transaction.method txn] args...
      delete pending[verToWrite++]
  , PENDING_INTERVAL
  
  return
