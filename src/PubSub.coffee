redis = require 'redis'
pathParser = require './pathParser'
transaction = require './transaction.server'
{hasKeys} = require './util'

# new PubSub
#   redis: {...}
#   pubClient: redisClientA
#   subClient: redisClientB
#   onMessage: (clientId, txn) ->
PubSub = module.exports = (options = {}) ->
  adapterName = options.adapter || 'Redis'
  onMessage = options.onMessage || ->
  @_adapter = new PubSub._adapters[adapterName] onMessage, options
  return

PubSub:: =
  subscribe: (subscriberId, paths, callback) ->
    @_adapter.subscribe subscriberId, paths, callback
  publish: (path, message) ->
    @_adapter.publish path, message
  unsubscribe: (subscriberId, paths, callback) ->
    @_adapter.unsubscribe subscriberId, paths, callback
  hasSubscriptions: (subscriberId) ->
    @_adapter.hasSubscriptions subscriberId
  subscribedToTxn: (subscriberId, txn) ->
    @_adapter.subscribedToTxn subscriberId, txn


PubSub._adapters = {}
PubSub._adapters.Redis = RedisAdapter = (onMessage, options) ->
  redisOptions = {port, host, db} = options.redis || {}
  namespace = (db || 0) + '.'
  @_namespace = (path) -> namespace + path

  unless @_publishClient = options.pubClient
    @_publishClient = redis.createClient port, host, redisOptions
    @_publishClient.select db if db
  unless @_subscribeClient = subClient = options.subClient
    @_subscribeClient = redis.createClient port, host, redisOptions

  @_subs = subs = {}
  @_subscriberSubs = {}

  if options.debug
    for event in ['subscribe', 'unsubscribe', 'psubscribe', 'punsubscribe']
      do (event) ->
        subClient.on event, (path, count) ->
          console.log "#{event.toUpperCase()} #{path} COUNT = #{count}"
    subClient.on 'message', (channel, message) ->
      console.log "MESSAGE #{channel} #{message}"
    subClient.on 'pmessage', (pattern, channel, message) ->
      console.log "PMESSAGE #{pattern} #{channel} #{message}"
    @__publish = RedisAdapter::publish
    @publish = (path, message) ->
      console.log "PUBLISH #{@_namespace path} #{JSON.stringify message}"
      @__publish path, message

  subClient.on 'pmessage', (pattern, path, message) ->
    # The pattern returned will have an extra * on the end
    if pathSubs = subs[pattern.substr(0, pattern.length - 1)]
      message = JSON.parse message
      for subscriberId, re of pathSubs
        onMessage subscriberId, message if re.test path

  # Redis doesn't support callbacks on subscribe or unsubscribe methods, so
  # we call the callback after subscribe/unsubscribe events are published on
  # each of the paths for a given call of subscribe/unsubscribe.
  makeCallback = (queue, event) ->
    subClient.on event, (path) ->
      if pending = queue[path]
        if callback = pending.shift()
          callback() unless --callback.__count
  makeCallback @_pendingSubscribe = {}, 'psubscribe'
  makeCallback @_pendingUnsubscribe = {}, 'punsubscribe'
  
  return

RedisAdapter:: =
  
  subscribe: (subscriberId, paths, callback) ->
    return if subscriberId is undefined

    subs = @_subs
    subscriberSubs = @_subscriberSubs
    toAdd = []
    for path in paths
      path = @_namespace path
      unless pathSubs = subs[path]
        subs[path] = pathSubs = {}
        toAdd.push path
      re = pathParser.regExp path
      pathSubs[subscriberId] = re
      ss = subscriberSubs[subscriberId] ||= {}
      ss[path] = re

    handlePaths toAdd, @_pendingSubscribe, @_subscribeClient,
      'psubscribe', callback

  publish: (path, message) ->
    path = @_namespace path
    @_publishClient.publish path, JSON.stringify message

  unsubscribe: (subscriberId, paths, callback) ->
    return if subscriberId is undefined

    # For signature: unsubscribe(subscriberId, callback)
    if typeof paths is 'function'
      callback = paths
      paths = null

    # For signature: unsubscribe(subscriberId[, callback])
    subscriberSubs = @_subscriberSubs
    paths ||= subscriberSubs[subscriberId] || []

    # For signature: unsubscribe(subscriberId, paths[, callback])
    subs = @_subs
    toRemove = []
    for path in paths
      path = @_namespace path
      if pathSubs = subs[path]
        delete pathSubs[subscriberId]
        toRemove.push path unless hasKeys pathSubs
      delete ss[path] if ss = subscriberSubs[subscriberId]

    handlePaths toRemove, @_pendingUnsubscribe, @_subscribeClient,
      'punsubscribe', callback

  hasSubscriptions: (subscriberId) -> subscriberId of @_subscriberSubs

  subscribedToTxn: (subscriberId, txn) ->
    path = @_namespace transaction.path txn
    for p, re of @_subscriberSubs[subscriberId]
      return true if p == path || re.test path
    return false

handlePaths = (paths, queue, client, fn, callback) ->
  if i = paths.length
    callback.__count = i if callback
  else
    callback() if callback
  while i--
    client[fn] path = paths[i] + '*'
    if callback
      (queue[path] ||= []).push callback
