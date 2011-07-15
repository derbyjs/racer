redis = require 'redis'
MemoryAdapter = require './adapters/Memory'
Model = require './Model'
Stm = require './Stm'
transaction = require './transaction'

PENDING_INTERVAL = 500

Store = module.exports = (AdapterClass = MemoryAdapter) ->
  @_adapter = adapter = new AdapterClass
  @_redisClient = redisClient = redis.createClient()
  stm = new Stm redisClient
  
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
      socket.on 'txn', (txn) ->
        commit txn, null, (err, txn) ->
          if err && err.code == 'STM_CONFLICT'
            socket.emit 'txnFail', transaction.id txn
      socket.on 'txnsSince', (ver) ->
        txnsSince ver, (txn) ->
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
      sockets.emit 'txn', txn if sockets
      pending[ver] = txn
  
  @_txnsSince = txnsSince = (ver, onTxn) ->
    redisClient.zrangebyscore 'txns', ver, '+inf', 'withscores', (err, vals) ->
      txn = null
      for val, i in vals
        if i % 2
          txn[0] = +val
          onTxn txn
        else
          txn = JSON.parse val
  
  populateModel = (model, paths, callback) ->
    return callback null, model unless path = paths.pop()
    adapter.get path, (err, value, ver) ->
      callback err if err
      model._adapter.set path, value, ver
      return populateModel model, paths, callback
  @subscribe = (model, paths..., callback) ->
    # TODO: Support path wildcards, references, and functions
    # If subscribe(callback)
    if model && !paths.length && !callback
      callback = model
      model = null

    if model
      # If subscribe(model, paths..., callback)
      if model instanceof Model
        return populateModel model, paths, callback

      # If subscribe(paths..., callback)
      paths.unshift model

    nextClientId (clientId) ->
      newModel = new Model clientId
      populateModel newModel, paths, callback
  
  @unsubscribe = ->
    throw "Unimplemented"
  
  @flush = (callback) ->
    done = false
    cb = (err) ->
      if callback && (done || err)
        callback err
        callback = null
      done = true
    adapter.flush cb
    redisClient.flushdb cb
  
  @get = adapter.get
  
  @set = (path, value, ver = null, callback) ->
    @_commit [ver, nextTxnId(), 'set', path, value], callback
  
  @del = (path, ver = null, callback) ->
    @_commit [ver, nextTxnId(), 'del', path], callback
  
  return
