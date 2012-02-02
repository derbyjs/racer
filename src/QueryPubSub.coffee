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

  # TODO Re-implement with looser coupling (channelPubSub.store is gnarly)
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
        unless q.test doc, nsPlusId
          if q.isPaginated && q.testWithoutPaging doc, nsPlusId
            if 'before' == q.beforeOrAfter doc
              # TODO TODO TODO TODO reactToPrevAdd
              q.reactToPrevAdd doc, channelPubSub
          continue
        channelPubSub.publish "queries.#{hash}", message
      return this

    for hash, q of queries
      queryChannel = "queries.#{hash}"
      if q.test origDoc, nsPlusId
        if q.test newDoc, nsPlusId
          # The query contains the document pre- and post-mutation,
          # so just publish the mutation
          channelPubSub.publish queryChannel, message
          return this

        # The query no longer contains the document,
        # so tell any subscribed clients to remove it.
        channelPubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: newDoc, hash, id: origDoc.id}
        if q.isPaginated
          # We just removed the document from the query result set.
          if q.testWithoutPaging newDoc, nsPlusId && 'before' == q.beforeOrAfter newDoc
            # If we moved this doc from the curr page to a prev page,
            # then grab the last member in the prev page and ushift it onto
            # the curr page
            query = newMemberQuery(TODO)
            store.query query, (err, found, ver) ->
              throw err if err
              if docToAdd = found[found.length-1]
                q._paginatedCache.unshift found[found.length-1]
                channelPubSub.publish queryChannel, addDoc: {ns: txnNs, doc: docToAdd, ver: pseudoVer()}
            return this

          # Otherwise, the doc does not satisfy *any* of the conditions,
          # or it was moved to a subsequent page. In either case, then
          # grab the first member of the next page and push it onto the curr
          # page
          query = newMemberQuery q, {push: 1}, channelPubSub.store
          channelPubSub.store.query query, (err, found, ver) ->
            throw err if err
            if docToAdd = found[0]
              channelPubSub.publish queryChannel, addDoc: {ns: txnNs, doc: docToAdd, ver: pseudoVer()}
          return this
        return this

      if testResult = q.test newDoc, nsPlusId
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
      else if q.isPaginated && q.testWithoutPaging origDoc, nsPlusId
        # The document that was mutated was in another page, satisfying the
        # conditions.

        unless q.testWithoutPaging newDoc, nsPlusId
          # Now, it is not supposed to be in any pages, so...
          # ... first, figure out which page the original doc was relative to the
          # current page: before or after?
          switch q.beforeOrAfter origDoc
            when 'before'
              # If the original doc was in a prior page, then we need to shift
              # the first doc in our current page of results to the previous
              # page, and we need to push the first doc in the next page of
              # results to the current page (if a next page exists)
              q.slideLeftInCache channelPubSub.store, (err, {shiftedDoc, pushedDoc}) ->
                throw err if err
                channelPubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: shiftedDoc, hash, id: shiftedDoc.id}
                channelPubSub.publish queryChannel, addDoc: {ns: txnNs, doc: pushedDoc, ver: pseudoVer()}
            when 'after'
              # If the original doc was on the next page, then removing it from
              # that page does not impact this page
              return this
            else throw new Error 'Impossible!'

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

# Cases:
#
#   <page prev> <page curr> <page next>
#                                         do nothing to curr
#
#   <page prev> <page curr> <page next>
#                   -                     push to curr from next
#
#   <page prev> <page curr> <page next>
#       +   <<<<<   -                     unshift to curr from prev
#
#   <page prev> <page curr> <page next>
#       -                                 shift from curr to prev
#                                         push to curr from right
#
#   <page prev> <page curr> <page next>
#       -   >>>>>   +                     shift from curr to prev
#                                         insert + in curr
#
#   <page prev> <page curr> <page next>
#       +                                 unshift to curr from prev
#                                         pop from curr to next
#
#   <page prev> <page curr> <page next>
#                   +                     pop from curr to next
#
#   <page prev> <page curr> <page next>
#                               -/+       do nothing to curr
#
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
        when 'where' then newQuery.where(currPath = args[0])
        when 'skip'  then skipOffset = args[0]
        when 'limit' then continue
        when 'sort'
          [path, dir] = args[0]
          switch dir
            when 'asc'
              val = lookup path, lastDoc
              if typeof val is 'number'
                skip = Math.min skip, countSimilar(cache, lastDoc, currPath, from: 'right')
                if skip == cache.length
                  skip += skipOffset
                else
                  newQuery.gte path, val # TODO What if there already exists a gt/gte?
            when 'desc'
              val = lookup path, lastDoc
              if typeof val is 'number'
                skip = Math.min skip, countSimilar(cache, lastDoc, currPath, from: 'right')
                if skip == cache.length
                  skip += skipOffset
                else
                  newQuery.lte path, val
          newQuery.sort args...
        else
          newQuery[method](args...)

    newQuery.limit 1
    newQuery.skip skip

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
    when 'left'
      throw new Error 'Unimplemented'
  return numSimilar
