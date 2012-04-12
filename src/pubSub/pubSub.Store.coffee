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

      nextTxnNum = {}
      store._txnClock = txnClock =
        unregister: (clientId) ->
          delete nextTxnNum[clientId]

        register: (clientId) ->
          nextTxnNum[clientId] = 1

        nextTxnNum: (clientId) ->
          @register clientId unless clientId of nextTxnNum
          nextTxnNum[clientId]++

      # TODO Move this behind the channel-interface-query abstraction
      pubSub.on 'noSubscribers', (path) ->
        delete liveQueries[path]

      # Live Query Channels
      # These following 2 channels are for informing a client about
      # changes to their data set based on mutations that add/rm docs
      # to/from the data set enclosed by the live queries the client
      # subscribes to.
      ['addDoc', 'rmDoc'].forEach (messageType) ->
        pubSub.on messageType, (clientId, data) ->
          num = txnClock.nextTxnNum clientId
          return unless socket = clientSockets[clientId]
          return socket.emit messageType, data, num

    socket: (store, socket, clientId) ->
      store._clientSockets[clientId] = socket

      socket.on 'disconnect', ->
        delete store._clientSockets[clientId]
        # Start buffering transactions on behalf of this disconnected client.
        # Buffering occurs for up to 3 seconds.
        store._startTxnBuffer clientId, 3000

      # Set up subscription cbs
      socket.on 'fetch', (targets, cb) ->
        # Only fetch data
        store.fetch clientId, deserialize(targets), cb

      socket.on 'addSub', (targets, cb) ->
        store.subscribeWithFetch clientId, deserialize(targets), cb

      socket.on 'removeSub', (targets, cb) ->
        store.unsubscribe clientId, deserialize(targets), cb

      # Check to see if this socket connection is
      # 1. The first connection after the server ships the bundled model to the browser.
      # 2. A connection that occurs shortly after an aberrant disconnect
      if store._txnBuffer clientId
        # If so, the store has been buffering any transactions meant to be
        # received by the (disconnected) browser model because of model subscriptions.

        # So stop buffering the transactions
        store._cancelTxnBufferExpiry clientId
        # And send the buffered transactions to the browser
        store._flushTxnBuffer clientId, socket
      else
        # Otherwise, the server store has completely forgotten about this
        # client because it has been disconnected too long. In this case, the
        # store should
        # 1. Ask the browser model what it is subscribed to, so we can re-establish subscriptions
        # 2. Send the browser model enough data to bring it up to speed with
        #    the current data snapshot according to the server. When the store uses a journal, then it can send the browser a set of missing transactions. When the store does not use a journal, then it sends the browser a new snapshot of what the browser is interested in; the browser can then set itself to the new snapshot and diff it against its stale snapshot to reply the diff to the DOM, which reflects the stale state.
        socket.emit 'resyncWithStore', (subs, clientVer, clientStartId) ->
          store._onSnapshotRequest clientVer, clientStartId, clientId, socket, subs, 'shouldSubscribe'


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

    subscribeWithoutFetch: (clientId, targets, cb) ->
      @_pubSub.subscribe clientId, targets, cb

    # Fetch the set of data represented by `targets` and subscribe to future
    # changes to this set of data.
    # @param {String} clientId representing the subscriber
    # @param {[String|Query]} targets (i.e., paths, or queries) to subscribe to
    # @param {Function} callback(err, data)
    subscribeWithFetch: subscribeWithFetch = (clientId, targets, cb) ->
      data = null
      finish = finishAfter 2, (err) ->
        cb err, data
      # This call to subscribe must come before the fetch, since a liveQuery
      # is created in subscribe that may be accessed during the fetch
      @subscribeWithoutFetch clientId, targets, finish
      @fetch clientId, targets, (err, _data) ->
        data = _data
        finish err

    subscribe: subscribeWithFetch

    unsubscribe: (clientId, targets, cb) ->
      @_pubSub.unsubscribe clientId, targets, cb

    publish: (path, type, data, meta) ->
      message = {type, params: {channel: path, data: data} }
      @_pubSub.publish message, meta

    _onSnapshotRequest: (ver, clientStartId, clientId, socket, subs, shouldSubscribe) ->
      @_checkVersion ver, clientStartId, (err) =>
        socket.emit 'fatalErr', err if err
        subs = deserialize subs
        if shouldSubscribe
          @subscribeWithoutFetch clientId, subs
        @_mode.snapshotSince {ver, clientId, subs}, (err, {data, txns}) =>
          socket.emit 'fatalErr', err if err
          num = @_txnClock.nextTxnNum clientId
          if data
            socket.emit 'snapshotUpdate:replace', data, num
          else if txns
            if len = txns.length
              socket.__ver = transaction.getVer txns[len - 1]
            socket.emit 'snapshotUpdate:newTxns', txns, num

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
