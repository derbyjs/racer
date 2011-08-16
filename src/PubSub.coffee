redis = require 'redis'
pathParser = require './pathParser.server'
transaction = require './transaction.server'
{hasKeys} = require './util'

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

  unless @_publishClient = options.pubClient
    ropts = {port, host, db} = options.redis || {}
    @_publishClient = redis.createClient(port, host, ropts)
    @_publishClient.select db if db
  unless @_subscribeClient = subClient = options.subClient
    ropts = {port, host, db} = options.redis || {}
    @_subscribeClient = redis.createClient port, host, ropts
    @_subscribeClient.select db if db

  @_subs = subs = {}
  @_subscriberSubs = {}
  
  if options.debug
    for event in ['subscribe', 'unsubscribe', 'psubscribe', 'punsubscribe']
      do (event) ->
        subClient.on event, (path, count) ->
    subClient.on 'message', (channel, message) ->
      console.log "MESSAGE #{channel} #{message}"
    subClient.on 'pmessage', (pattern, channel, message) ->
      console.log "PMESSAGE #{pattern} #{channel} #{message}"
    @__publish = RedisAdapter::publish
    @publish = (path, message) ->
      console.log "PUBLISH #{path} #{JSON.stringify message}"
      @__publish path, message
  
  _onMessage = (glob, path, message) ->
    message = JSON.parse message
    if subscribers = subs[glob]
      for key, [subscriberId, re] of subscribers
        onMessage subscriberId, message if re.test path
  
  subClient.on 'message', (path, message) -> _onMessage path, path, message
  subClient.on 'pmessage', _onMessage
  
  # Redis doesn't support callbacks on subscribe or unsubscribe methods, so
  # we call the callback after subscribe/unsubscribe events are published on
  # each of the paths for a given call of subscribe/unsubscribe
  makeCallback = (queue, events) ->
    fn = (path) ->
      if pending = queue[path]
        if callback = pending.shift()
          callback() unless --callback.__count
    for event in events
      subClient.on event, fn
  makeCallback @_pendingSubscribe = {}, ['subscribe', 'psubscribe']
  makeCallback @_pendingUnsubscribe = {}, ['unsubscribe', 'punsubscribe']
  
  return

RedisAdapter:: =
  
  subscribe: (subscriberId, paths, callback) ->
    return if subscriberId is undefined
    
    subs = @_subs
    subscriberSubs = @_subscriberSubs
    toAdd = []
    for path in paths
      glob = pathParser.glob path
      unless globSubs = subs[glob]
        subs[glob] = globSubs = {}
        toAdd.push glob
      re = pathParser.regExp path
      # Two different path patterns may map to the same glob pattern, so the
      # subscriptions are indexed both by subscriberId and path
      globSubs["#{subscriberId}$#{path}"] = [subscriberId, re]
      subscriberSubs[subscriberId] = ss = subscriberSubs[subscriberId] || {}
      ss[path] = re
    
    handlePaths toAdd, @_pendingSubscribe, @_subscribeClient,
      'subscribe', 'psubscribe', callback

  publish: (path, message) ->
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
      glob = pathParser.glob path
      if globSubs = subs[glob]
        delete globSubs["#{subscriberId}$#{path}"]
        toRemove.push glob unless hasKeys globSubs
      ss = subscriberSubs[subscriberId]
      delete ss[path] if ss
    
    handlePaths toRemove, @_pendingUnsubscribe, @_subscribeClient,
      'unsubscribe', 'punsubscribe', callback
  
  hasSubscriptions: (subscriberId) -> subscriberId of @_subscriberSubs

  subscribedToTxn: (subscriberId, txn) ->
    path = transaction.path txn
    for p, re of @_subscriberSubs[subscriberId]
      return true if p == path || re.test path
    return false

handlePaths = (paths, queue, client, pathFn, patternFn, callback) ->
  if i = paths.length
    callback.__count = i if callback
  else
    callback() if callback
  while i--
    path = paths[i]
    if pathParser.isGlob path
      client[patternFn] path
    else
      client[pathFn] path
    if callback
      queue[path] = pending = queue[path] || []
      pending.push callback
