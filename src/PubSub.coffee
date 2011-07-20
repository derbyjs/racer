pathParser = require './pathParser'

PubSub = module.exports = (adapterName, options) ->
  @_adapter = new PubSub._adapters[adapterName] this, options
  return

PubSub:: =
  subscribe: (subscriberId, path, callback) ->
    @_adapter.subscribe arguments...

  publish: (publisherId, path, message) ->
    @_adapter.publish arguments...
  
  unsubscribe: (subscriberId, path, callback) ->
    @_adapter.unsubscribe arguments...

PubSub._adapters = {}
redis = require 'redis'
# redis.debug_mode = true
PubSub._adapters.Redis = RedisAdapter = (pubsub, options = {}) ->
  @_pathsBySubscriber = {}
  @_subscribersByPath = {}
  @_patternsBySubscriber = {}
  @_subscribersByPattern = {}

  @_publishClient = options.client || redis.createClient()
  @_subscribeClient = redis.createClient()

  @_subscribeClient.on 'subscribe', (path, count) =>
    if @debug
      console.log "SUBSCRIBING #{path} - COUNT = #{count}"
    return
  @_subscribeClient.on 'message', (path, message) =>
    # TODO Invert this for performance? i.e., function calls
    # are expensive, so place for loop in the onMessage function
    # and do the same for `@_subscribeClient.on 'pmessage'...`
    for subscriberId in @_subscribersByPath[path]
      pubsub.onMessage subscriberId, JSON.parse message
  @_subscribeClient.on 'unsubscribe', (path, count) =>
    if @debug
      console.log "UNSUBSCRIBING #{path} - COUNT = #{count}"
    return

  @_subscribeClient.on 'psubscribe', (pattern, count) ->
    if @debug
      console.log "PSUBSCRIBING #{pattern} - COUNT = #{count}"
    return
  @_subscribeClient.on 'pmessage', (pattern, channel, message) =>
    message = JSON.parse message
    subscribers = @_subscribersByPattern[pattern]
    if subscribers
      for subscriberId in subscribers
        pubsub.onMessage subscriberId, message
    subscribers = @_subscribersByPath[channel]
    if subscribers
      for subscriberId in subscribers
        pubsub.onMessage subscriberId, message
  @_subscribeClient.on 'punsubcribe', (pattern, count) ->
    if @debug
      console.log "PUNSUBSCRIBING #{pattern} - COUNT = #{count}"
    return

  return

RedisAdapter:: =
  _index: (subscriberId, path, pathType) ->
    paths = @['_' + pathType.toLowerCase() + 'sBySubscriber'][subscriberId] ||= []
    paths.push path

    subscribers = @['_subscribersBy' + pathType][path] ||= []
    subscribers.push subscriberId

  _unindex: (subscriberId, path, pathType) ->
    if (path)
      paths = @['_' + pathType.toLowerCase() + 'sBySubscriber'][subscriberId]
      paths.splice(paths.indexOf(path), 1)

      subscribers = @['_subscribersBy' + pathType][path]
      subscribers.splice(subscribers.indexOf(subscriberId), 1)
    else
      # More efficient way to remove *all* traces of a subscriber
      # than evaling above if multiple times
      for pathType in ['Pattern', 'Path']
        paths = @['_' + pathType.toLowerCase() + 'sBySubscriber'][subscriberId]
        delete @['_' + pathType.toLowerCase() + 'sBySubscriber'][subscriberId]
        for path in paths
          subscribers = @['_subscribersBy' + pathType][path]
          subscribers.splice(subscribers.indexOf(subscriberId), 1)

  _alreadySubscribed: (path) -> !!(@_subscribersByPath[path] || @_subscribersByPattern[path])

  subscribe: (subscriberId, path, callback) ->
    return if 'undefined' == typeof subscriberId
    [paths, patterns, exceptions] = pathParser.forSubscribe path

    for path in paths
      @_subscribeClient.subscribe path unless @_alreadySubscribed path
      @_index subscriberId, path, 'Path'
    for pattern in patterns
      @_subscribeClient.psubscribe pattern unless @_alreadySubscribed path
      @_index subscriberId, path, 'Pattern'

  publish: (publisherId, path, message) ->
    if @debug
      console.log "PUBLISHING the following to #{path}:"
      console.log message
    @_publishClient.publish path, JSON.stringify message

  unsubscribe: (subscriberId, path, callback) ->
    if path
      [paths, patterns, exceptions] = pathParser.forSubscribe path

      for path in paths
        @_subscribeClient.unsubscribe path unless @_alreadySubscribed path
        @_unindex subscriberId, path
      for pattern in patterns
        @_subscribeClient.punsubscribe pattern unless @_alreadySubscribed path
        @_unindex subscriberId, path
    else
      @_subscribeClient.unsubscribe

# TODO PubSub._adapters.Memory = MemoryAdapter
