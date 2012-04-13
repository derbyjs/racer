{isServer, deepCopy, finishAfter} = require '../../util'
console.assert isServer

Memory = require '../../Memory'
transaction = require '../../transaction.server'
LiveQuery = require '../../pubSub/LiveQuery'
{deserialize: deserializeQuery} = require '../../pubSub/Query'

module.exports = queryInterface = (pubSub, store) ->
  # subscriberId -> (query hash -> true)
  reverseIndex = {}


  liveQueries = store._liveQueries

  intf = {}

  intf.subscribe = (subscriberId, query, ackCb) ->
    hash = query.hash()

    hashes = reverseIndex[subscriberId] ||= {}
    hashes[hash] = true

    liveQueries[hash] ||= new LiveQuery query
    pubSub.string.subscribe subscriberId, ["$q.#{hash}"], ackCb

  intf.publish = ({type, params}, meta) ->
    return unless type == 'txn' && meta
    {data: txn} = params
    unless origDoc = meta.origDoc
      return publish store, params, meta

    newDoc = if origDoc
              deepCopy origDoc
            else
              # Otherwise, this is a new doc
              transaction.getArgs(txn)[1]

    newDoc = applyTxn txn, newDoc
    publish store, params, origDoc, newDoc

  intf.unsubscribe = (subscriberId, query, ackCb) ->
    unless query?.isQuery
      hashes = reverseIndex[subscriberId]
      delete reverseIndex[subscriberId]
      channels = ("$q.#{hash}" for hash of hashes)
      if ackCb = query
        ackCb = finishAfter channels.length, ackCb
    else
      channels = ["$q.#{query.hash()}"]

    return ackCb? null unless channels.length
    pubSub.unsubscribe subscriberId, channels, ackCb

  intf.hasSubscriptions = (subscriberId) ->
    return subscriberId of reverseIndex

  intf.subscribedTo = (subscriberId, query) ->
    # TODO Probably a more efficient way to do this
    return pubSub.subscribedTo subscriberId, "$q.#{query.hash()}"

  return intf

publish = (store, params, origDoc, newDoc) ->
  {data: txn} = params
  txnVer = transaction.getVer txn
  pseudoVer = -> txnVer += 0.01
  txnPath = transaction.getPath txn
  [txnNs, txnId] = parts = txnPath.split '.'
  nsPlusId = txnNs + '.' + txnId
  {_liveQueries: liveQueries, _pubSub: pubSub} = store

  if transaction.getMethod(txn) == 'set' && parts.length == 2
    # If we are setting an entire document
    doc = transaction.getArgs(txn)[1]
    for hash, query of liveQueries
      channel = "$q.#{hash}"
      if query.isPaginated
        continue unless query.testWithoutPaging doc, nsPlusId
        query.updateCache store, (err, newMembers, oldMembers, ver) ->
          throw err if err
          for mem in newMembers
            pubSub.publish
              type: 'addDoc'
              params:
                channel: channel
                data: {ns: txnNs, doc: mem, ver: pseudoVer()}
          for mem in oldMembers
            pubSub.publish
              type: 'rmDoc'
              params:
                channel: channel
                data: {ns: txnNs, doc: mem, hash, id: mem.id, ver: pseudoVer()}
      continue unless query.test doc, nsPlusId
      if !query.isPaginated || (query.isPaginated && query.isCacheImpactedByTxn txn)
        pubSub.publish channel, params
        pubSub.publish
          type: 'txn'
          params:
            channel: channel
            data: txn
    return

  for hash, query of liveQueries
    channel = "$q.#{hash}"
    if query.isPaginated
      if (query.testWithoutPaging(origDoc, nsPlusId) || query.testWithoutPaging(newDoc, nsPlusId))
        # TODO Optimize for non-saturated case
        query.updateCache store, (err, newMembers, oldMembers, ver) ->
          throw err if err
          for mem in newMembers
            pubSub.publish
              type: 'addDoc'
              params:
                channel: channel
                data: {ns: txnNs, doc: mem, ver: pseudoVer()}
          for mem in oldMembers
            pubSub.publish
              type: 'rmDoc'
              params:
                channel: channel
                data: {ns: txnNs, doc: mem, hash, id: mem.id, ver: pseudoVer()}
          if query.isCacheImpactedByTxn txn
            pubSub.publish
              type: 'txn'
              params:
                channel: channel
                data: txn
          return

    else if query.test origDoc, nsPlusId
      if query.test newDoc, nsPlusId
        # The query contains the document pre- and post-mutation,
        # so just publish the mutation
        pubSub.publish
          type: 'txn'
          params:
            channel: channel
            data: txn
      else
        # The query no longer contains the document,
        # so tell any subscribed clients to remove it.
        pubSub.publish
          type: 'rmDoc'
          params:
            channel: channel
            data: {ns: txnNs, doc: newDoc, hash, id: origDoc.id, ver: pseudoVer()}

    # The query didn't contain the document before its mutation, but now it
    # does contain it, so tell the client to add the document to its model.
    else if query.test newDoc, nsPlusId
      pubSub.publish
        type: 'addDoc'
        params:
          channel: channel
          data: {ns: txnNs, doc: newDoc, ver: pseudoVer()}
      # But also send along the original mutation just in case
      # the client is also subscribed to another query that matched this document
      # pre-mutation but not post-mutation. In this case, the client should keep
      # the doc knowing that one query begins to match a doc at the same time another
      # query fails to match the doc
      pubSub.publish
        type: 'txn'
        params:
          channel: channel
          data: txn

    # The query didn't contain the doument before the mutation.
    # It also doesn't contain the document after the mutation.

    # Else the document mutation may impact the paginated set, despite not being
    # in the page of interest.

  return

memory = new Memory
memory.setVersion = ->
applyTxn = (txn, doc) ->
  method = transaction.getMethod txn
  args = transaction.getArgs txn
  path = transaction.getPath txn
  if method == 'del' && path.split('.').length == 2
    return undefined
  [ns, id] = path.split '.'
  world = {}
  world[ns] = {}
  world[ns][id] = doc
  data = {world}
  try
    memory[method] args..., -1, data
  catch err then
  return doc
