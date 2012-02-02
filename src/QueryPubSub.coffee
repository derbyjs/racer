transaction = require './transaction.server'
{lookup} = require './pathParser'
createQuery = require './query'

# Appraoch:
# Every mutation returns a full doc or docs. We pass that doc and the diff
# through a subset of queries to decide (a) which queries to remove this doc
# from and (b) which queries to add this doc to
LiveQuery = require './LiveQuery'
deserializeQuery = require('./query').deserialize

QueryPubSub = module.exports = (@_channelPubSub) ->
  @_liveQueries = {}
  return

QueryPubSub::=
  subscribe: (subscriberId, queries, callback) ->
    liveQs = @_liveQueries
    channels = []
    for query in queries
      liveQuery = deserializeQuery query.serialize(), LiveQuery
      queryHash = query.hash()
      liveQs[queryHash] = liveQuery
      channels.push "queries.#{queryHash}"
    @_channelPubSub.subscribe subscriberId, channels, callback, 'subscribe'
    return this

  publish: (message, origDoc, newDoc) ->
    return this unless txn = message.txn # vs message.ot
    txnVer = transaction.base txn
    pseudoVer = -> txnVer += 0.2
    txnPath = transaction.path txn
    [txnNs, txnId] = parts = txnPath.split '.'
    nsPlusId = txnNs + '.' + txnId
    queries = @_liveQueries
    channelPubSub = @_channelPubSub

    if transaction.method(txn) == 'set' && parts.length == 2
      # If we are setting an entire document
      doc = transaction.args(txn)[1]
      for hash, q of queries
        continue unless q.test doc, nsPlusId
        channelPubSub.publish "queries.#{hash}", message
      return this

    for hash, q of queries
      queryChannel = "queries.#{hash}"
      if q.test origDoc, nsPlusId
        if q.test newDoc, nsPlusId
          # The query contains the document pre- and post-mutation,
          # so just publish the mutation
          channelPubSub.publish queryChannel, message
        else
          # The query no longer contains the document,
          # so tell any subscribed clients to remove it.
          channelPubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: newDoc, hash, id: origDoc.id}
          if q.isPaginated
            # We just removed the document from the query result set.
            # If the query result set is a paginated subset of all results
            # satisfying the query conditions, then find a document in the
            # from this larger set of results that can take the place of the
            # removed document.
            query = newMemberQuery q, {push: 1}, channelPubSub.store
            # TODO Re-implement with looser coupling (channelPubSub.store
            #      is gnarly)
            channelPubSub.store.query query, (err, found, ver) ->
              throw err if err
              if docToAdd = found[0]
                channelPubSub.publish queryChannel, addDoc: {ns: txnNs, doc: docToAdd, ver: pseudoVer()}
      else if testResult = q.test newDoc, nsPlusId
        # The query didn't contain the document before its mutation, but now it
        # does contain it, so tell the client to add the document to its model.
        channelPubSub.publish queryChannel, addDoc: {ns: txnNs, doc: newDoc, ver: pseudoVer()}
        # But also send along the original mutation just in case
        # the client is also subscribed to another query that already matches
        # this document
        channelPubSub.publish queryChannel, message
        if q.isPaginated
          if docToRm = testResult.rmDoc
            channelPubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: docToRm, hash, id: docToRm.id}

    return this

  unsubscribe: (subscriberId, queries, callback) ->
    liveQs = @_liveQueries
    channels = []
    for q in queries
      hash = q.hash()
      delete liveQs[hash]
      channels.push hash
    @_channelPubSub.unsubscribe subscriberId, channels, callback

  getQueryCache: (query) ->
    if liveQuery = @_liveQueries[query.hash()]
      return liveQuery._paginatedCache

  setQueryCache: (query, cache) ->
    if liveQuery = @_liveQueries[query.hash()]
      liveQuery._paginatedCache = cache

newMemberQuery = (liveQuery, {push, unshift}, store) ->
  cache = liveQuery._paginatedCache
  newQuery = createQuery()
  if push isnt undefined
    skip = cache.length
    skipOffset = 0
    lastDoc = cache[skip-1]
    queryParams = liveQuery.serialize()
    for [method, args] in queryParams
      switch method
        when 'where'
          currPath = args[0]
          newQuery.where currPath
        when 'lt'
          newQuery.lt args[0]
          newQuery.gte lookup(currPath, lastDoc)
          skip = Math.min skip, countSimilar(cache, lastDoc, currPath, from: 'right')
        when 'lte'
          newQuery.lte args[0]
          newQuery.gte lookup(currPath, lastDoc)
          skip = Math.min skip, countSimilar(cache, lastDoc, currPath, from: 'right')
        when 'gt'
          newQuery.gt args[0]
          newQuery.lte lookup(currPath, lastDoc)
          skip = Math.min skip, countSimilar(cache, lastDoc, currPath, from: 'right')
        when 'gte'
          newQuery.gte args[0]
          newQuery.lte lookup(currPath, lastDoc) # TODO what if there already exists a lt/lte?
                                                 # TODO Doesn't this depend on
                                                 #      sort params?
          skip = Math.min skip, countSimilar(cache, lastDoc, currPath, from: 'right')
        when 'skip' then skipOffset = args[0]
        when 'limit' then continue
        else
          newQuery[method].apply newQuery, args
    newQuery.limit 1
    newQuery.skip(skip + skipOffset)

  return newQuery

countSimilar = (cache, doc, path, {from}) ->
  switch from
    when 'right'
      return 0 unless len = cache.length
      i = len-1
      numSimilar = 1
      while mem = cache[--i]
        if lookup(path, mem) == lookup(path, doc)
          numSimilar++
        else
          break
  return numSimilar
