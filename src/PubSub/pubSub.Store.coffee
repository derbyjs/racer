queryPubSub = require './queryPubSub'
{deserialize: deserializeQuery} = require './Query'
{split: splitPath, lookup} = require '../path'
{finishAfter} = require '../util'

module.exports =
  type: 'Store'

  events:
    init: (store) ->
      store._liveQueries = liveQueries = {}
      store._clientSockets = clientSockets = {}
      pubSub = store._pubSub
      journal = store._journal

      pubSub.on 'noSubscribers', (path) ->
        delete liveQueries[path]

      pubSub.on 'message', (clientId, [type, data]) ->
        pubSub.emit type, clientId, data

      # Live Query Channels
      # These following 2 channels are for informing a client about
      # changes to their data set based on mutations that add/rm docs
      # to/from the data set enclosed by the live queries the client
      # subscribes to.
      ['addDoc', 'rmDoc'].forEach (message) ->
        pubSub.on message, (clientId, data) ->
          journal.nextTxnNum clientId, (err, num) ->
            throw err if err
            return clientSockets[clientId].emit message, data, num

    socket: (store, socket) ->

      # Called when a client first connects
      socket.on 'sub', (clientId, targets, ver, clientStartId) ->

        store._clientSockets[clientId] = socket
        socket.on 'disconnect', ->
          store.unsubscribe clientId
          store._journal.unregisterClient clientId
          delete store._clientSockets[clientId]

        # This promise is created in the txns.Store mixin
        socket._clientIdPromise.fulfill clientId

        store._checkVersion socket, ver, clientStartId, (err) ->
          return if err

          socket.on 'fetch', (clientId, targets, callback) ->
            store.fetch clientId, deserialize(targets), callback

          # Called from already connected clients
          socket.on 'subAdd', (clientId, targets, callback) ->
            # Setup subscriptions and fetch data
            store.subscribe clientId, deserialize(targets), callback

          socket.on 'subRemove', (clientId, targets, callback) ->
            store.unsubscribe clientId, deserialize(targets), callback

          # Setup subscriptions only
          send 'subscribe', store, clientId, deserialize(targets)

  proto:
    fetch: (clientId, targets, callback) ->
      data = []
      otData = {}
      finish = finishAfter targets.length, (err) ->
        callback err, data, otData

      otFields = @_otFields
      for target in targets
        if target.isQuery
          fetchQueryData this, data, target, finish
        else
          [root, remainder] = splitPath target
          fetchPathData this, data, otData, root, remainder, otFields, finish
      return

    # Fetch the set of data represented by `targets` and subscribe to future
    # changes to this set of data.
    # @param {String} clientId representing the subscriber
    # @param {[String|Query]} targets (i.e., paths, or queries) to subscribe to
    # @param {Function} callback(err, data, otData)
    subscribe: (clientId, targets, callback) ->
      data = otData = null
      finish = finishAfter 2, (err) ->
        callback err, data, otData
      @fetch clientId, targets, (err, _data, _otData) ->
        data = _data
        otData = _otData
        finish err
      send 'subscribe', this, clientId, targets, finish

    unsubscribe: (clientId, targets, callback) ->
      send 'unsubscribe', this, clientId, targets, callback

    publish: (path, type, data, meta) ->
      message = [type, data]
      queryPubSub.publish this, path, message, meta
      @_pubSub.publish path, message

    query: (query, callback) ->
      # TODO Add in an optimization later since query._paginatedCache
      # can be read instead of going to the db. However, we must make
      # sure that the cache is a consistent snapshot of a given moment
      # in time. i.e., no versions of the cache should exist between
      # an add/remove combined action that should be atomic but currently
      # isn't

      # TODO Improve this de/serialize API
      dbQuery = deserializeQuery query.serialize(), @_db.Query
      dbQuery.run @_db, (err, found, xf) =>
        # TODO Get version consistency right in face of concurrent writes during
        # query
        if Array.isArray found
          if xf then for doc in found
            xf doc
        else if xf
          xf found
        callback err, found, @_db.version


deserialize = (targets) ->
  for target, i in targets
    if Array.isArray target
      # Deserialize query literal into a Query instance
      targets[i] = deserializeQuery target
  return targets

send = (method, store, clientId, targets, callback) ->
  if targets
    channels = []
    queries = []
    for target in targets
      queue = if target.isQuery then queries else channels
      queue.push target
    numChannels = channels.length
    numQueries = queries.length
    count = if numChannels && numQueries then 2 else 1
    finish = finishAfter count, callback
    if numQueries
      queryPubSub[method] store, clientId, queries, finish
    if numChannels
      store._pubSub[method] clientId, channels, finish
    return

  # Unsubscribing without any targets removes all subscriptions
  # for a given clientId
  finish = finishAfter 2, callback
  queryPubSub[method] store, clientId, null, finish
  store._pubSub[method] clientId, null, finish

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
