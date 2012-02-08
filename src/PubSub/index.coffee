transaction = require '../transaction.server'
{deepCopy} = require '../util'
QueryPubSub = require '../QueryPubSub'
RedisAdapter = require './adapters/Redis'

PubSub = module.exports = (options = {}) ->
  onMessage = options.onMessage || ->
  @_adapter = options.adapter
  @_adapter.onMessage = onMessage
  @_queryPubSub = new QueryPubSub this
  @store = options.store
  return

PubSub:: =
  subscribe: (subscriberId, targets, callback, method = 'psubscribe') ->
    channels = []
    queries = []
    for targ in targets
      if targ.isQuery
        queries.push targ
      else channels.push targ
    numChannels = channels.length
    numQueries = queries.length
    remaining = if numChannels && numQueries then 2 else 1
    if numQueries
      @_queryPubSub.subscribe subscriberId, queries, (err) ->
        --remaining || callback()
    if numChannels
      @_adapter.subscribe subscriberId, channels, (err) ->
        --remaining || callback()
      , method

  publish: (path, message, meta = {}) ->
    unless path.substring(0,8) == 'queries.'
      if origDoc = meta.origDoc
        {txn} = message
        if origDoc
          newDoc = deepCopy origDoc
        else
          # Otherwise, this is a new doc
          newDoc = transaction.args(txn)[1]
        newDoc = applyTxn txn, newDoc
        @_queryPubSub.publish message, origDoc, newDoc
      else
        @_queryPubSub.publish message
    @_adapter.publish path, message

  unsubscribe: (subscriberId, channels, callback) ->
    @_adapter.unsubscribe subscriberId, channels, callback

  hasSubscriptions: (subscriberId) ->
    @_adapter.hasSubscriptions subscriberId

  subscribedToTxn: (subscriberId, txn) ->
    @_adapter.subscribedToTxn subscriberId, txn

  getQueryCache: (query) ->
    @_queryPubSub.getQueryCache query

  setQueryCache: (query, cache) ->
    @_queryPubSub.setQueryCache query, cache

# TODO
eachTargetType = (targets, callbackByType) ->
  queries = []
  paths = []
  for targ in targets
    if targ.isQuery
      queries.push targ
    else
      paths.push targ
  callbackByType.queries queries
  callbackByType.pathPatterns paths


MemorySync = require '../adapters/MemorySync'
adapter = new MemorySync
adapter.setVersion = ->
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
  adapter[method] args..., 0, data
  return doc
