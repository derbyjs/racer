{split: splitPath, lookup} = require '../path'
{finishAfter} = require '../util/async'
{hasKeys} = require '../util'
racer = require '../racer'
PubSub = require './PubSub'

{deserialize: deserializeQuery} = require './Query'
deserialize = (targets) ->
  for target, i in targets
    if Array.isArray target
      # Deserialize query literal into a Query instance
      targets[i] = deserializeQuery target
  return targets


module.exports =
  type: 'Store'

  events:
    init: (store, opts) ->
      pubSub = store._pubSub = new PubSub

      store._liveQueries = liveQueries = {}
      store._clientSockets = clientSockets = {}
      journal = store._journal

      pubSub.on 'noSubscribers', (path) ->
        delete liveQueries[path]

      # Live Query Channels
      # These following 2 channels are for informing a client about
      # changes to their data set based on mutations that add/rm docs
      # to/from the data set enclosed by the live queries the client
      # subscribes to.
      ['addDoc', 'rmDoc'].forEach (messageType) ->
        pubSub.on messageType, (clientId, data) ->
          journal.nextTxnNum clientId, (err, num) ->
            throw err if err
            return clientSockets[clientId].emit messageType, data, num

    socket: (store, socket, clientId) ->
      store._clientSockets[clientId] = socket
      socket.on 'disconnect', ->
        delete store._clientSockets[clientId]

      # Called when a client first connects
      socket.on 'sub', (clientId, targets, ver, clientStartId) ->

        socket.on 'disconnect', ->
          store.unsubscribe clientId
          store._journal.unregisterClient clientId

        store._checkVersion socket, ver, clientStartId, (err) ->
          return socket.emit 'fatalErr', err if err

          socket.on 'fetch', (targets, callback) ->
            # Only fetch data
            store.fetch clientId, deserialize(targets), callback

          socket.on 'addSub', (targets, callback) ->
            # Setup subscriptions and fetch data
            store.subscribe clientId, deserialize(targets), callback

          socket.on 'removeSub', (targets, callback) ->
            store.unsubscribe clientId, deserialize(targets), callback

          # Setup subscriptions only
          store._pubSub.subscribe clientId, deserialize(targets)

  proto:
    # TODO fetch does not belong in pubSub
    fetch: (clientId, targets, callback) ->
      data = []
      finish = finishAfter targets.length, (err) =>
        return callback err if err
        out = {data}
        # Note that `out` may be mutated by ot or other plugins
        @emit 'fetch', out, clientId, targets
        callback null, out

      for target in targets
        if target.isQuery
          # TODO Make this consistent with fetchPathData
          fetchQueryData this, target, (path, datum, ver) ->
            data.push [path, datum, ver]
          , finish
        else
          fetchPathData this, target, (path, datum, ver) ->
            data.push [path, datum, ver]
          , finish
      return

    # Fetch the set of data represented by `targets` and subscribe to future
    # changes to this set of data.
    # @param {String} clientId representing the subscriber
    # @param {[String|Query]} targets (i.e., paths, or queries) to subscribe to
    # @param {Function} callback(err, data)
    subscribe: (clientId, targets, callback) ->
      data = null
      finish = finishAfter 2, (err) ->
        callback err, data
      # This call to subscribe must come before the fetch, since a liveQuery
      # is created in subscribe that may be accessed during the fetch
      @_pubSub.subscribe clientId, targets, finish
      @fetch clientId, targets, (err, _data) ->
        data = _data
        finish err

    unsubscribe: (clientId, targets, callback) ->
      @_pubSub.unsubscribe clientId, targets, callback

    publish: (path, type, data, meta) ->
      message = {type, params: {channel: path, data: data} }
      @_pubSub.publish message, meta
#      message = [type, data]
#      queryPubSub.publish this, path, message, meta
#      @_pubSub.publish path, message

    # TODO Move this into another module?
    query: (query, callback) ->
      # TODO Add in an optimization later since query._paginatedCache
      # can be read instead of going to the db. However, we must make
      # sure that the cache is a consistent snapshot of a given moment
      # in time. i.e., no versions of the cache should exist between
      # an add/remove combined action that should be atomic but currently
      # isn't
      db = @_db
      liveQueries = @_liveQueries
      dbQuery = new db.Query query
      dbQuery.run db, (err, found) ->
        if query.isPaginated && Array.isArray(found) && (liveQuery = liveQueries[query.hash()])
          liveQuery._paginatedCache = found
        # TODO Get version consistency right in face of concurrent writes
        # during query
        callback err, found, db.version

fetchPathData = (store, path, eachDatumCb, onComplete) ->
  [root, remainder] = splitPath path
  store.get root, (err, datum, ver) ->
    return onComplete err if err
    unless remainder?
      eachDatumCb path, datum, ver
    else
      # The path contains looks like <root>.*.<remainder>,
      # so set each property one level down
      patternMatchingDatum root, remainder, datum, (fullPath, datum) ->
        eachDatumCb fullPath, datum, ver
    return onComplete null

# @param {String} prefix is the part of the path up to ".*."
# @param {String} remainder is the part of the path after ".*."
# @param {Object} subDoc is the lookup value of the prefix
# @param {Function} eachDatumCb is the callback for each datum matching the pattern
patternMatchingDatum = (prefix, remainder, subDoc, eachDatumCb) ->
  [appendToPrefix, remainder] = splitPath remainder
  for property, value of subDoc
    unless value.constructor == Object || Array.isArray value
      # We can't lookup `appendToPrefix` on `value` in this case
      continue

    newPrefix = prefix + '.' + property + '.' + appendToPrefix
    newValue = lookup appendToPrefix, value
    unless remainder?
      eachDatumCb newPrefix, newValue
    else
      patternMatchingDatum newPrefix, remainder, newValue, eachDatumCb

# TODO Add in an optimization later since query._paginatedCache
# can be read instead of going to the db. However, we must make
# sure that the cache is a consistent snapshot of a given moment
# in time. i.e., no versions of the cache should exist between
# an add/remove combined action that should be atomic but currently
# isn't
# TODO Get version consistency right in face of concurrent writes
# during query
fetchQueryData = (store, query, eachDatumCb, finish) ->
  store.query query, (err, result, version) ->
    return finish err if err

    if Array.isArray result
      for doc in result
        path = query.namespace + '.' + doc.id
        eachDatumCb path, doc, version
    else if result
      path = query.namespace + '.' + result.id
      eachDatumCb path, result, version
    finish null
