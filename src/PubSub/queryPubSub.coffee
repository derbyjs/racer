Memory = require '../Memory'
transaction = require '../transaction.server'
{deepCopy} = require '../util'
LiveQuery = require './LiveQuery'
{deserialize} = require './Query'

module.exports =
  subscribe: (store, subscriberId, queries, callback) ->
    liveQueries = store._liveQueries
    channels = []
    for query in queries
      hash = query.hash()
      channels.push "queries.#{hash}"
      liveQueries[hash] ||= deserialize query.serialize(), LiveQuery

    store._pubSub.subscribe subscriberId, channels, callback, true

  unsubscribe: (store, subscriberId, queries, callback) ->
    if queries
      channels = []
      for query in queries
        hash = query.hash()
        channels.push "queries.#{hash}"
    else
      channels = null

    store._pubSub.unsubscribe subscriberId, channels, callback, true

  publish: (store, path, message, meta) ->
    return if path[0..7] == 'queries.'
    if origDoc = meta.origDoc
      {txn} = message
      if origDoc
        newDoc = deepCopy origDoc
      else
        # Otherwise, this is a new doc
        newDoc = transaction.args(txn)[1]
      newDoc = applyTxn txn, newDoc
      publish store, message, origDoc, newDoc
    else
      publish store, message, meta

publish = (store, message, origDoc, newDoc) ->
  return unless txn = message.txn # vs message.ot
  txnVer = transaction.base txn
  pseudoVer = -> txnVer += 0.01
  txnPath = transaction.path txn
  [txnNs, txnId] = parts = txnPath.split '.'
  nsPlusId = txnNs + '.' + txnId
  liveQueries = store._liveQueries
  pubSub = store._pubSub

  if transaction.method(txn) == 'set' && parts.length == 2
    # If we are setting an entire document
    doc = transaction.args(txn)[1]
    for hash, query of liveQueries
      queryChannel = "queries.#{hash}"
      if query.isPaginated
        continue unless query.testWithoutPaging doc, nsPlusId
        query.updateCache store, (err, newMembers, oldMembers, ver) ->
          throw err if err
          for mem in newMembers
            pubSub.publish queryChannel, addDoc: {ns: txnNs, doc: mem, ver: pseudoVer()}
          for mem in oldMembers
            pubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: mem, hash, id: mem.id, ver: pseudoVer()}
      continue unless query.test doc, nsPlusId
      if !query.isPaginated || (query.isPaginated && query.isCacheImpactedByTxn txn)
        pubSub.publish queryChannel, message
    return

  for hash, query of liveQueries
    queryChannel = "queries.#{hash}"
    if query.isPaginated
      if (query.testWithoutPaging(origDoc, nsPlusId) || query.testWithoutPaging(newDoc, nsPlusId))
        # TODO Optimize for non-saturated case
        query.updateCache pubSub.store, (err, newMembers, oldMembers, ver) ->
          throw err if err
          for mem in newMembers
            pubSub.publish queryChannel, addDoc: {ns: txnNs, doc: mem, ver: pseudoVer()}
          for mem in oldMembers
            pubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: mem, hash, id: mem.id, ver: pseudoVer()}
          if query.isCacheImpactedByTxn txn
            pubSub.publish queryChannel, message
          return

    else if query.test origDoc, nsPlusId
      if query.test newDoc, nsPlusId
        # The query contains the document pre- and post-mutation,
        # so just publish the mutation
        pubSub.publish queryChannel, message
      else
        # The query no longer contains the document,
        # so tell any subscribed clients to remove it.
        pubSub.publish queryChannel, rmDoc: {ns: txnNs, doc: newDoc, hash, id: origDoc.id, ver: pseudoVer()}
    # The query didn't contain the document before its mutation, but now it
    # does contain it, so tell the client to add the document to its model.
    else if query.test newDoc, nsPlusId
      pubSub.publish queryChannel, addDoc: {ns: txnNs, doc: newDoc, ver: pseudoVer()}
      # But also send along the original mutation just in case
      # the client is also subscribed to another query that matched this document
      # pre-mutation but not post-mutation. In this case, the client should keep
      # the doc knowing that one query begins to match a doc at the same time another
      # query fails to match the doc
      pubSub.publish queryChannel, message

    # The query didn't contain the doument before the mutation.
    # It also doesn't contain the document after the mutation.

    # Else the document mutation may impact the paginated set, despite not being
    # in the page of interest.

memory = new Memory
memory.setVersion = ->
applyTxn = (txn, doc) ->
  method = transaction.method txn
  args = transaction.args txn
  path = transaction.path txn
  if method == 'del' && path.split('.').length == 2
    return undefined
  [ns, id] = path.split '.'
  world = {}
  world[ns] = {}
  world[ns][id] = doc
  data = {world}
  try
    memory[method] args..., 0, data
  catch err then
  return doc
