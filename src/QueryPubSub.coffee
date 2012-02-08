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
    pseudoVer = -> txnVer += 0.01
    txnPath = transaction.path txn
    [txnNs, txnId] = parts = txnPath.split '.'
    nsPlusId = txnNs + '.' + txnId
    queries = @_liveQueries
    channelPubSub = @_channelPubSub

    if transaction.method(txn) == 'set' && parts.length == 2
      # If we are setting an entire document
      doc = transaction.args(txn)[1]
      for hash, q of queries
        queryChannel = "queries.#{hash}"
        if q.isPaginated
          continue unless q.testWithoutPaging doc, nsPlusId
          q.updateCache channelPubSub.store, (err, newMembers, oldMembers, ver) ->
            throw err if err
            for mem in newMembers
              channelPubSub.publish queryChannel, addDoc: {ns: txnNs, doc: mem, ver: pseudoVer()}
            for mem in oldMembers
              channelPubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: mem, hash, id: mem.id, ver: pseudoVer()}
        continue unless q.test doc, nsPlusId
        if !q.isPaginated || (q.isPaginated && q.isCacheImpactedByTxn txn)
          channelPubSub.publish queryChannel, message
      return this

    for hash, q of queries
      queryChannel = "queries.#{hash}"
      if q.isPaginated
        if (q.testWithoutPaging(origDoc, nsPlusId) || q.testWithoutPaging(newDoc, nsPlusId))
          # TODO Optimize for non-saturated case
          q.updateCache channelPubSub.store ,(err, newMembers, oldMembers, ver) ->
            throw err if err
            for mem in newMembers
              channelPubSub.publish queryChannel, addDoc: {ns: txnNs, doc: mem, ver: pseudoVer()}
            for mem in oldMembers
              channelPubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: mem, hash, id: mem.id, ver: pseudoVer()}
            if q.isCacheImpactedByTxn txn
              channelPubSub.publish queryChannel, message
            return

      else if q.test origDoc, nsPlusId
        if q.test newDoc, nsPlusId
          # The query contains the document pre- and post-mutation,
          # so just publish the mutation
          channelPubSub.publish queryChannel, message
        else
          # The query no longer contains the document,
          # so tell any subscribed clients to remove it.
          channelPubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: newDoc, hash, id: origDoc.id, ver: pseudoVer()}
      # The query didn't contain the document before its mutation, but now it
      # does contain it, so tell the client to add the document to its model.
      else if q.test newDoc, nsPlusId
        channelPubSub.publish queryChannel, addDoc: {ns: txnNs, doc: newDoc, ver: pseudoVer()}
        # But also send along the original mutation just in case
        # the client is also subscribed to another query that matched this document
        # pre-mutation but not post-mutation. In this case, the client should keep
        # the doc knowing that one query begins to match a doc at the same time another
        # query fails to match the doc
        channelPubSub.publish queryChannel, message

      # The query didn't contain the doument before the mutation.
      # It also doesn't contain the document after the mutation.

      # Else the document mutation may impact the paginated set, despite not being
      # in the page of interest.
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

# Cases for mutations impacting paginated queries
#
#   <page prev> <page curr> <page next>
#                                         do nothing to curr
#
#+  <page prev> <page curr> <page next>
#                   -                     push to curr from next
#
#+  <page prev> <page curr> <page next>
#       +   <<<<<   -                     unshift to curr from prev
#
#+  <page prev> <page curr> <page next>
#       -                                 shift from curr to prev
#                                         push to curr from right
#
#+  <page prev> <page curr> <page next>
#       -   >>>>>   +                     shift from curr to prev
#                                         insert + in curr
#
#+  <page prev> <page curr> <page next>
#       -   >>>>>>>>>>>>>>>>>   +         shift from curr to prev
#                                         push from next to curr
#
#+  <page prev> <page curr> <page next>
#       +                                 unshift to curr from prev
#                                         pop from curr to next
#
#+  <page prev> <page curr> <page next>
#                   +                     pop from curr to next
#
#   <page prev> <page curr> <page next>
#                               -/+       do nothing to curr
#
#+  <page prev> <page curr> <page next>
#                   -><-                  re-arrange curr members
