redis = require 'redis'
MemoryAdapter = require './adapters/Memory'
Model = require './Model.server'
Stm = require './Stm'
PubSub = require './PubSub'
transaction = require './transaction'
pathParser = require './pathParser'
TxnApplier = require './TxnApplier'
specHelper = require './specHelper'
redisInfo = require './redisInfo'
Promise = require './Promise'
Field = require './mixin.ot/Field.server'

# store = new Store
#   adapter: SomeAdapter
#   redis:
#     port: xxxx
#     host: xxxx
#     db:   xxxx
Store = module.exports = (options = {}) ->
  self = this
  Adapter = options.Adapter || MemoryAdapter
  @_adapter = adapter = new Adapter

  {port, host, db} = redisOptions = options.redis || {}
  # Client for data access and event publishing
  @_redisClient = redisClient = redis.createClient(port, host, redisOptions)
  # Client for internal Racer event subscriptions
  @_subClient = subClient = redis.createClient(port, host, redisOptions)
  # Client for event subscriptions of txns only
  @_txnSubClient = txnSubClient = redis.createClient(port, host, redisOptions)

  # Maps path -> { listener: fn, queue: [msg], busy: bool }
  # TODO Encapsulate this at a lower level of abstraction
  @otFields = otFields = {}

  # TODO: Make sure there are no weird race conditions here, since we are
  # caching the value of starts and it could potentially be stale when a
  # transaction is received
  # TODO: Make sure this works when redis crashes and is restarted
  redisStarts = null
  startIdPromise = new Promise
  # Calling select right away queues the command before any commands that
  # a client might add before connect happens. If select is not queued first,
  # the subsequent commands could happen on the wrong db
  ignoreSubscribe = false
  do subscribeToStarts = (selected) ->
    return ignoreSubscribe = false if ignoreSubscribe
    if db isnt undefined && !selected
      return redisClient.select db, (err) ->
        throw err if err
        subscribeToStarts true
    redisInfo.subscribeToStarts subClient, redisClient, (starts) ->
      redisStarts = starts
      startIdPromise.clearValue() if startIdPromise.value
      startIdPromise.fulfill starts[0][0]
  
  # Ignore the first connect event
  ignoreSubscribe = true
  redisClient.on 'connect', subscribeToStarts
  redisClient.on 'end', ->
    redisStarts = null
    startIdPromise.clearValue()


  ## Downstream Transactional Interface ##

  # Redis clients used for subscribe, psubscribe, unsubscribe,
  # and punsubscribe cannot be used with any other commands.
  # Therefore, we can only pass the current `redisClient` as the
  # pubsub's @_publishClient.
  @_localModels = localModels = {}
  onTxnMsg = (clientId, txn) ->
    # Don't send transactions back to the model that created them.
    # On the server, the model directly handles the store._commit callback.
    # Over Socket.io, a 'txnOk' message is sent below.
    return if clientId == transaction.clientId txn
    # For models only present on the server, process the transaction
    # directly in the model
    return model._onTxn txn if model = localModels[clientId]
    # Otherwise, send the transaction over Socket.io
    if socket = clientSockets[clientId]
      # Prevent sending duplicate transactions by only sending new versions
      base = transaction.base txn
      if base > socket.__base
        socket.__base = base
        nextTxnNum clientId, (num) ->
          socket.emit 'txn', txn, num
  onOtMsg = (clientId, ot) ->
    if socket = clientSockets[clientId]
      return if socket.id == ot.meta.src
      socket.emit 'otOp', ot
  @_pubSub = pubSub = new PubSub
    redis: redisOptions
    pubClient: redisClient
    subClient: txnSubClient
    onMessage: (clientId, {txn, ot}) ->
      return onTxnMsg clientId, txn if txn
      return onOtMsg clientId, ot

  @_nextTxnNum = nextTxnNum = (clientId, callback) ->
    redisClient.incr 'txnClock.' + clientId, (err, value) ->
      throw err if err
      callback value

  hasInvalidVer = (socket, ver, clientStartId) ->
    # Don't allow a client to connect unless there is a valid startId to
    # compare the model's against
    unless startIdPromise.value
      socket.disconnect()
      return true
    # TODO: Map the client's version number to the Stm's and update the client
    # with the new startId unless the client's version includes versions that
    # can't be mapped
    unless clientStartId && clientStartId == startIdPromise.value
      socket.emit 'fatalErr'
      return true
    return false
  
  clientSockets = {}
  @_setSockets = (sockets) -> sockets.on 'connection', (socket) ->
    # TODO Once socket.io supports query params in the
    # socket.io urls, then we can remove this. Instead,
    # we can add the socket <-> clientId assoc in the
    # `sockets.on 'connection'...` callback.
    socket.on 'sub', (clientId, paths, ver, clientStartId) ->
      return if hasInvalidVer socket, ver, clientStartId

      # TODO Map the clientId to a nickname (e.g., via session?), and broadcast presence
      #      to subscribers of the relevant namespace(s)
      socket.on 'disconnect', ->
        pubSub.unsubscribe clientId
        delete clientSockets[clientId]
        redisClient.del 'txnClock.' + clientId, (err, value) ->
          throw err if err

      socket.on 'subAdd', (clientId, paths, callback) ->
        pubSub.subscribe clientId, paths
        self._fetchSubData paths, (err, data) ->
          callback data

      socket.on 'subRemove', (clientId, paths) ->
        throw 'Unimplemented: subRemove'

      # Handling OT messages
      socket.on 'otSnapshot', (setNull, fn) ->
        # Lazy create/snapshot the OT doc
        if field = self.otFields[path]
          # TODO
          TODO = 'TODO'

      socket.on 'otOp', (msg, fn) ->
        {path, op, v} = msg

        flushViaFieldClient = ->
          unless fieldClient = field.client socket.id
            fieldClient = field.registerSocket socket
            # TODO Cleanup with field.unregisterSocket
          fieldClient.queue.push [msg, fn]
          fieldClient.flush()

        # Lazy create the OT doc
        unless field = self.otFields[path]
          field = self.otFields[path] = new Field self._adapter, self._pubSub, path, v
          self._adapter.get path, (err, val, ver) ->
            # Lazy snapshot initialization
            snapshot = field.snapshot = val?.$ot || ''
            flushViaFieldClient()
        else
          flushViaFieldClient()


      # Handling transaction messages
      socket.on 'txn', (txn, clientStartId) ->
        base = transaction.base txn
        return if hasInvalidVer socket, base, clientStartId
        commit txn, (err, txn) ->
          txnId = transaction.id txn
          base = transaction.base txn
          # Return errors to client, with the exeption of duplicates, which
          # may need to be sent to the model again
          return socket.emit 'txnErr', err, txnId if err && err != 'duplicate'
          nextTxnNum clientId, (num) ->
            socket.emit 'txnOk', txnId, base, num
      
      socket.on 'txnsSince', txnsSince = (ver, clientStartId) ->
        return if hasInvalidVer socket, ver, clientStartId
        # Reset the pending transaction number in the model
        redisClient.get 'txnClock.' + clientId, (err, value) ->
          throw err if err
          socket.emit 'txnNum', value || 0
          forTxnSince ver, clientId, (txn) ->
            nextTxnNum clientId, (num) ->
              socket.__base = transaction.base txn
              socket.emit 'txn', txn, num
      
      # This is used to prevent emitting duplicate transactions
      socket.__base = 0
      # Set up subscriptions to the store for the model
      clientSockets[clientId] = socket

      # We guard against the following race condition:
      # Window 1 and Window 2 are both snapshotted at the same ver.
      # Window 1 commits a txn A. Window 1 subscribes.
      # Window 2 subscribes, but before the server can publish the
      # txn A that it missed, Window 1 publishes txn B that
      # is immediately broadcast to Window 2 just before txn A is
      # broadcast to Window 2.
      pubSub.subscribe clientId, paths
      # Return any transactions that the model may have missed
      txnsSince ver + 1, clientStartId
  
  # Accumulates an array of tuples [root, remainder, value, ver]
  #
  # @param {Array} data is an array that gets mutated
  # @param {String} root is the part of the path up to ".*"
  # @param {String} remainder is the part of the path ".*" and beyond
  # @param {Object} value is the lookup value of the rooth path
  # @param {Number} ver is the lookup ver of the root path
  addSubDatum = (data, root, remainder, value, ver) ->
    # Set the entire object if the remainder is '', which indicates
    # that the path ended in a '*'
    if remainder == ''
      return data.push [root, remainder, value, ver]

    # Set only the specified property if there is no remainder
    unless remainder?
      value = if typeof value is 'object'
          if specHelper.isArray value then [] else {}
        else value
      return data.push [root, remainder, value, ver]

    # Set each property one level down, since the path had a '*'
    # following the current root
    [appendRoot, remainder] = pathParser.split remainder
    for prop of value
      nextRoot = if root then root + '.' + prop else prop
      nextValue = value[prop]
      if appendRoot
        nextRoot += '.' + appendRoot
        nextValue = pathParser.fastLookup appendRoot, nextValue
      addSubDatum data, nextRoot, remainder, nextValue, ver
    return

  @_fetchSubData = (paths, callback) ->
    remainingGets = paths.length
    data = []
    otData = {}
    store = this
    for path in paths
      [root, remainder] = pathParser.split path

      @get root, (err, value, ver) ->
        return callback err  if err
        # TODO Make ot field detection more accurate. Should cover all remainder scenarios.
        # TODO Convert the following to work beyond MemoryStore
        otPaths = allOtPaths value, root + '.'
        for otPath in otPaths
          otData[otPath] = otField if otField = store.otFields[otPath]

        # addSubDatum mutates data
        addSubDatum data, root, remainder, value, ver
        return if --remainingGets
        callback null, data, otData
    return

  @_forTxnSince = forTxnSince = (ver, clientId, onTxn, done) ->
    return unless pubSub.hasSubscriptions clientId
    
    # TODO Replace with a LUA script that does filtering?
    redisClient.zrangebyscore 'txns', ver, '+inf', 'withscores', (err, vals) ->
      throw err if err
      txn = null
      for val, i in vals
        if i % 2
          continue unless pubSub.subscribedToTxn clientId, txn
          transaction.base txn, +val
          onTxn txn
        else
          txn = JSON.parse val
      done() if done

  nextClientId = (callback) ->
    redisClient.incr 'clientClock', (err, value) ->
      throw err if err
      callback value.toString(36)

  @createModel = ->
    model = new Model
    model.store = self
    model._ioUri = self._ioUri
    model.startIdPromise = startIdPromise
    startIdPromise.on (startId) -> model._startId = startId
    nextClientId (clientId) -> model.clientIdPromise.fulfill clientId
    return model

  @flush = (callback) ->
    done = false
    cb = (err) ->
      if callback && (done || err)
        callback err
        callback = null
      done = true
    adapter.flush cb
    redisClient.flushdb (err) ->
      if err && callback
        callback err
        return callback = null
      redisInfo.onStart redisClient, cb

  @model = @createModel()
  for key, val of @model.async
    @[key] = val

  ## Upstream Transaction Interface ##

  stm = new Stm redisClient
  @_commit = commit = (txn, callback) ->
    ver = transaction.base txn
    if ver && typeof ver isnt 'number'
      # In case of something like @set(path, value, callback)
      throw new Error 'Version must be null or a number'
    stm.commit txn, (err, ver) ->
      transaction.base txn, ver
      callback err, txn if callback
      return if err
      pubSub.publish transaction.path(txn), txn: txn
      txnApplier.add txn, ver
  
  ## Ensure Serialization of Transactions to the DB ##
  # TODO: This algorithm will need to change when we go multi-process,
  # because we can't count on the version to increase sequentially
  txnApplier = new TxnApplier
    applyTxn: (txn, ver) ->
      args = transaction.args(txn).slice 0
      method = transaction.method txn
      args.push ver, (err) ->
        # TODO: Better adapter error handling and potentially a second callback
        # to the caller of commit when the adapter operation completes
        throw err if err
      adapter[method] args...

  @disconnect = ->
    [redisClient, subClient, txnSubClient].forEach (client) -> client.quit()

  return

allOtPaths = (obj, prefix = '') ->
  results = []
  return results unless obj && obj.constructor is Object
  for k, v of obj
    if v && v.constructor is Object
      if v.$ot
        results.push prefix + k
        continue
      results.push allOtPaths(v, k + '.')...
  return results
