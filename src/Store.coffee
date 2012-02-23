redis = require 'redis'
PubSub = require './PubSub'
MemoryAdapter = require './adapters/Memory'
Model = require './Model.server'
transaction = require './transaction'
{split: splitPath, lookup, eventRegExp} = require './pathParser'
Field = require './mixin.ot/Field.server'
{bufferify} = require './util'
{deserialize: deserializeQuery} = require './query'
PubSubRedisAdapter = require './PubSub/adapters/Redis'
Promise = require './Promise'

Journal = require './Journal'
JournalRedisAdapter = require './Journal/adapters/Redis'

# store = new Store
#   mode: 'lww' || 'stm' || 'ot'
#   pubSub:
#     adapter: new PubSubRedisAdapter({ pubClient: clientA, subClient:
#              clientB})
#   generateClientId:
#     strategy: 'redis'
#     opts:
#       redisClient: redisClient
#   journal:
#     adapter: new JournalRedisAdapter(redisClient, subClient)
Store = module.exports = (options = {}) ->
  self = this

  [redisClient, subClient, txnSubClient] = setupRedis self, options.redis
  self.disconnect = ->
    redisClient.end()
    subClient.end()
    txnSubClient.end()

  pubSubAdapter = options.pubSub?.adapter ||
    new PubSubRedisAdapter pubClient: redisClient, subClient: txnSubClient

  @_pubSub = new PubSub
    store: @
    adapter: pubSubAdapter
    onMessage: (clientId, msg) ->
      {txn, ot, rmDoc, addDoc} = msg
      return self._onTxnMsg clientId, txn if txn
      return self._onOtMsg clientId, ot if ot

      # Live Query Channels
      # These following 2 channels are for informing a client about
      # changes to their data set based on mutations that add/rm docs
      # to/from the data set enclosed by the live queries the client
      # subscribes to.
      if socket = self._clientSockets[clientId]
        if rmDoc
          return journal.nextTxnNum clientId, (err, num) ->
            throw err if err
            return socket.emit 'rmDoc', rmDoc, num
        if addDoc
          return journal.nextTxnNum clientId, (err, num) ->
            throw err if err
            return socket.emit 'addDoc', addDoc, num
      throw new Error 'Unsupported message: ' + JSON.stringify(msg, null, 2)

  if clientIdGenConf = options.generateClientId
    {strategy, opts} = clientIdGenConf
  else
    strategy = 'rfc4122.v4'
    opts = {}
  createFn = require "./clientIdGenerators/#{strategy}"
  @_generateClientId = createFn opts

  # Add a @commit method to this store based on the conflict resolution mode
  journalAdapter = options.journal?.adapter || new JournalRedisAdapter redisClient, subClient
  journal = @journal = new Journal journalAdapter
  @commit = journal.commitFn self, options.mode

  # Maps path -> { listener: fn, queue: [msg], busy: bool }
  # TODO Encapsulate this at a lower level of abstraction
  @_otFields = {}

  @_localModels = {}

  @_adapter = options.adapter || new MemoryAdapter

  # This model is used to create transactions with id's
  # prefixed with '#', so we handle store's async mutations
  # differently than regular models' sync mutations
  @_model = @_createStoreModel()
  # TODO Figure out a way to not have a whole @_model around

  @_persistenceRoutes = {}
  @_defaultPersistenceRoutes = {}
  for method in ['get', 'set', 'del', 'setNull', 'incr', 'push',
    'unshift', 'insert', 'pop', 'shift', 'remove', 'move']
    @_persistenceRoutes[method] = []
    @_defaultPersistenceRoutes[method] = []
  @_adapter.setupDefaultPersistenceRoutes this

  return

Store:: =

  _createStoreModel: ->
    model = @createModel()
    for key, val of model.async
      continue if key == 'get'
      # TODO Beware: mixing in has danger of naming conflicts; better to
      #      delegate to @_model.async instead.
      # TODO Define store mutators here instead of copying from Async because
      #      using Async from here ends up making a hop back to here before
      #      accessing store again (e.g., async.model.store._adapter). Instead
      #      we can be more direct (e.g., @_adapter)
      @[key] = val
    return model

  query: (query, callback) ->
    self = this

    # TODO Add in an optimization later since query._paginatedCache
    # can be read instead of going to the db. However, we must make
    # sure that the cache is a consistent snapshot of a given moment
    # in time. i.e., no versions of the cache should exist between
    # an add/remove combined action that should be atomic but currently
    # isn't

    # TODO Improve this de/serialize API
    dbQuery = deserializeQuery query.serialize(), self._adapter.Query
    dbQuery.run self._adapter, (err, found, xf) ->
      # TODO Get version consistency right in face of concurrent writes during
      # query
      if Array.isArray found
        if xf then for doc in found
          xf doc
        if query.isPaginated
          self._pubSub.setQueryCache(query, found)
      else if xf
        xf found
      callback err, found, self._adapter.version

  get: (path, callback) -> @sendToDb 'get', [path], callback

  createModel: ->
    model = new Model
    model.store = this
    model._ioUri = @_ioUri
    startIdPromise = model.startIdPromise = new Promise
    @journal.startId (startId) ->
      model._startId = startId
      startIdPromise.fulfill startId
    @_generateClientId (err, clientId) ->
      throw err if err
      model.clientIdPromise.fulfill clientId
    return model

  flush: (callback) ->
    rem = 2
    cb = (err) ->
      if !(--rem) || err
        callback err if callback
        return callback = null
    @flushJournal cb
    @flushDb cb

  flushJournal: (callback) ->
    self = this
    @journal.flush (err) ->
      return callback err if err
      self._model = self._createStoreModel()
      callback null

  flushDb: (callback) -> @_adapter.flush callback

  _finishCommit: (txn, ver, callback) ->
    transaction.base txn, ver
    args = transaction.args(txn).slice()
    method = transaction.method txn
    args.push ver
    self = this
    @sendToDb method, args, (err, origDoc) ->
      # TODO De-couple publish from db write
      self._pubSub.publish transaction.path(txn), {txn}, {origDoc}
      callback err, txn if callback

  setSockets: (@sockets, @_ioUri = '') ->
    self = this

    @_clientSockets = clientSockets = {}
    pubSub = @_pubSub
    journal = @journal

    # TODO: These are for OT, which is hacky. Clean up
    otFields = @_otFields
    adapter = @_adapter

    # TODO Once socket.io supports query params in the
    # socket.io urls, then we can remove this. Instead,
    # we can add the socket <-> clientId assoc in the
    # `sockets.on 'connection'...` callback.
    sockets.on 'connection', (socket) -> socket.on 'sub', (clientId, targets, ver, clientStartId) ->
      return if journal.hasInvalidVer socket, ver, clientStartId

      # TODO Map the clientId to a nickname (e.g., via session?),
      # and broadcast presence
      socket.on 'disconnect', ->
        pubSub.unsubscribe clientId
        delete clientSockets[clientId]
        journal.unregisterClient clientId, (err, val) ->
          throw err if err

      # Called when subscribing from an already connected client
      socket.on 'subAdd', (clientId, targets, callback) ->
        for target, i in targets
          if Array.isArray target
            # Deserialize query JSON into a Query instance
            targets[i] = deserializeQuery target

        self.subscribe clientId, targets, callback

      socket.on 'subRemove', (clientId, targets) ->
        throw 'Unimplemented: subRemove'

      # Handling OT messages
      socket.on 'otSnapshot', (setNull, fn) ->
        # Lazy create/snapshot the OT doc
        if field = otFields[path]
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
        unless field = otFields[path]
          field = otFields[path] =
            new Field self, pubSub, path, v
          # TODO Replace with sendToDb
          adapter.get path, (err, val, ver) ->
            # Lazy snapshot initialization
            snapshot = field.snapshot = val?.$ot || ''
            flushViaFieldClient()
        else
          flushViaFieldClient()

      # Handling transaction messages
      socket.on 'txn', (txn, clientStartId) ->
        base = transaction.base txn
        return if journal.hasInvalidVer socket, base, clientStartId
        self.commit txn, (err, txn) ->
          txnId = transaction.id txn
          base = transaction.base txn
          # Return errors to client, with the exeption of duplicates, which
          # may need to be sent to the model again
          return socket.emit 'txnErr', err, txnId if err && err != 'duplicate'
          journal.nextTxnNum clientId, (err, num) ->
            throw err if err
            socket.emit 'txnOk', txnId, base, num

      socket.on 'txnsSince', (ver, clientStartId, callback) ->
        return if journal.hasInvalidVer socket, ver, clientStartId
        journal.txnsSince ver, clientId, pubSub, (err, txns) ->
          return callback err if err
          journal.nextTxnNum clientId, (err, num) ->
            throw err if err
            if len = txns.length
              socket.__base = transaction.base txns[len-1]
            callback txns, num

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
      pubSub.subscribe clientId, targets, ->

  _onTxnMsg: (clientId, txn) ->
    # Don't send transactions back to the model that created them.
    # On the server, the model directly handles the store.commit callback.
    # Over Socket.io, a 'txnOk' message is sent below.
    return if clientId == transaction.clientId txn
    # For models only present on the server, process the transaction
    # directly in the model
    return model._onTxn txn if model = @_localModels[clientId]
    # Otherwise, send the transaction over Socket.io
    if socket = @_clientSockets[clientId]
      # Prevent sending duplicate transactions by only sending new versions
      base = transaction.base txn
      if base > socket.__base
        socket.__base = base
        @journal.nextTxnNum clientId, (err, num) ->
          throw err if err
          socket.emit 'txn', txn, num

  _onOtMsg: (clientId, ot) ->
    if socket = @_clientSockets[clientId]
      return if socket.id == ot.meta.src
      socket.emit 'otOp', ot

  registerLocalModel: (model) -> @_localModels[model._clientId] = model

  unregisterLocalModel: (model) -> delete @_localModels[model._clientId]

  # Fetch the set of data represented by `targets` and subscribe to future
  # changes to this set of data.
  # @param {String} clientId representing the subscriber
  # @param {[String|Query]} targets (i.e., paths, or queries) to subscribe to
  # @param {Function} callback(err, data, otData)
  subscribe: (clientId, targets, callback) ->
    # One possible race condition:
    # 1. ClientA sends a subscription request to pubSub
    # 2. ClientA sends a request for data to the db
    # 3. ClientB is mutating data. It publishes to pubSub. The message is
    #    published to any subscribers at this time. It simultaneously sends
    #    a write request to the db.
    # 4. ClientA's requests to pubSub and the db occur afterwards.
    # 5. ClientB's write to the db succeeds
    # 6. However, now we're in a state where ClientA has a copy of the data
    #    without the mutation.
    # Solution: We take care of this after the replicated data is sent to the
    # browser. The browser model asks the server for any updates like this it
    # may have missed.
    count = 2
    data = null
    otData = null
    err = null
    finish = (_err) ->
      err ||= _err
      --count || callback err, data, otData
    @_pubSub.subscribe clientId, targets, finish
    fetchSubData this, targets, (err, _data, _otData) ->
      data = _data
      otData = _otData
      finish err

  unsubscribe: (clientId) -> @_pubSub.unsubscribe clientId

  ## PERSISTENCE ROUTER ##
  route: (method, path, fn) ->
    re = eventRegExp path
    @_persistenceRoutes[method].push [re, fn]
    return this

  defaultRoute: (method, path, fn) ->
    re = eventRegExp path
    @_defaultPersistenceRoutes[method].push [re, fn]
    return this

  sendToDb:
    bufferify 'sendToDb',
      await: (done) ->
        adapter = @_adapter
        return done() if adapter.version isnt undefined
        @journal.getVer (err, ver) ->
          throw err if err
          adapter.version = parseInt(ver, 10)
          return done()
      origFn: (method, args, done) ->
        perRoutes = @_persistenceRoutes
        defPerRoutes = @_defaultPersistenceRoutes
        routes = perRoutes[method].concat defPerRoutes[method]
        [path, rest...] = args
        done ||= (err) ->
          throw err if err
        i = 0
        do next = ->
          unless handler = routes[i++]
            throw new Error "No persistence handler for #{method}(#{args.join(', ')})"
          [re, fn] = handler
          return next() unless path == '' || (match = path.match re)
          captures = if path == ''
              ['']
            else if match.length > 1
              match[1..]
            else
              [match[0]]
          return fn.apply null, captures.concat(rest, [done, next])

# Accumulates an array of tuples to set [path, value, ver]
#
# @param {Array} data is an array that gets mutated
# @param {String} root is the part of the path up to ".*"
# @param {String} remainder is the part of the path after "*"
# @param {Object} value is the lookup value of the rooth path
# @param {Number} ver is the lookup ver of the root path
addSubDatum = (data, root, remainder, value, ver) ->
  # Set the entire object
  return data.push [root, value, ver]  unless remainder?

  # Set each property one level down, since the path had a '*'
  # following the current root
  [appendRoot, remainder] = splitPath remainder
  for prop of value
    nextRoot = if root then root + '.' + prop else prop
    nextValue = value[prop]
    if appendRoot
      nextRoot += '.' + appendRoot
      nextValue = lookup appendRoot, nextValue

    addSubDatum data, nextRoot, remainder, nextValue, ver
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

fetchPathData = (store, data, otData, root, remainder, otFields, finish) ->
  store.get root, (err, value, ver) ->
    # TODO Make ot field detection more accurate. Should cover all remainder scenarios.
    # TODO Convert the following to work beyond MemoryStore
    otPaths = allOtPaths value, root + '.'
    for otPath in otPaths
      otData[otPath] = otField if otField = otFields[otPath]

    # addSubDatum mutates data argument
    addSubDatum data, root, remainder, value, ver
    finish err

queryResultAsDatum = (doc, ver, query) ->
  path = query.namespace + '.' + doc.id
  return [path, doc, ver]

fetchQueryData = (store, data, query, finish) ->
  store.query query, (err, found, ver) ->
    if Array.isArray found
      for doc in found
        data.push queryResultAsDatum(doc, ver, query)
    else
      data.push queryResultAsDatum(found, ver, query)
    finish err

fetchSubData = (store, targets, callback) ->
  data = []
  otData = {}

  count = targets.length
  err = null
  finish = (_err) ->
    err ||= _err
    --count || callback err, data, otData

  otFields = store._otFields
  for target in targets
    if target.isQuery
      fetchQueryData store, data, target, finish
    else
      [root, remainder] = splitPath target
      fetchPathData store, data, otData, root, remainder, otFields, finish
  return

maybeHandleErr = (err) -> throw err if err

setupRedis = (redisOptions = {}) ->
  {port, host, db, password} = redisOptions
  # Client for data access and event publishing
  redisClient = redis.createClient(port, host, redisOptions)

  # TODO Use only one subscription client, and leverage multi-plexing

  # Client for internal Racer event subscriptions
  subClient = redis.createClient(port, host, redisOptions)
  # Client for event subscriptions of txns only
  txnSubClient = redis.createClient(port, host, redisOptions)

  if password
    redisClient.auth password, maybeHandleErr
    subClient.auth password, maybeHandleErr
    txnSubClient.auth password, maybeHandleErr

  return [redisClient, subClient, txnSubClient]
