{EventEmitter} = require 'events'
pathRegExp = hasKeys = null

module.exports = (racer) ->
  {regExp: pathRegExp} = racer.path
  {hasKeys} = racer.util
  racer.adapters.pubSub.Memory = PubSubMemory

PubSubMemory = ->
  @_pathSubs = {}
  @_patternSubs = {}
  @_subscriberPathSubs = {}
  @_subscriberPatternSubs = {}
  return

PubSubMemory:: =
  __proto__: EventEmitter::

  publish: (path, message) ->
    for pattern, subs of @_patternSubs
      continue unless subsMatchPath subs, path
      for subscriberId of subs
        @emit 'message', subscriberId, message

    if subs = @_pathSubs[path]
      for subscriberId of subs
        @emit 'message', subscriberId, message

  subscribe: (subscriberId, paths, callback, isLiteral) ->
    throw new Error 'undefined subscriberId'  unless subscriberId?

    if isLiteral
      subs = @_pathSubs
      subscriberSubs = @_subscriberPathSubs
    else
      subs = @_patternSubs
      subscriberSubs = @_subscriberPatternSubs

    ss = subscriberSubs[subscriberId] ||= {}
    for path in paths
      value = if isLiteral then true else pathRegExp path
      s = subs[path] ||= {}
      s[subscriberId] = ss[path] = value

    callback?()

  unsubscribe: (subscriberId, paths, callback, isLiteral) ->
    throw new Error 'undefined subscriberId'  unless subscriberId?

    if isLiteral
      subs = @_pathSubs
      subscriberSubs = @_subscriberPathSubs
    else
      subs = @_patternSubs
      subscriberSubs = @_subscriberPatternSubs

    ss = subscriberSubs[subscriberId]
    paths = paths || (ss && Object.keys ss) || []

    for path in paths
      delete ss[path]  if ss
      if s = subs[path]
        delete s[subscriberId]
        unless hasKeys s
          delete subs[path]
          @emit 'noSubscribers', path

    callback?()

  hasSubscriptions: (subscriberId) ->
    (subscriberId of @_subscriberPatternSubs) || (subscriberId of @_subscriberPathSubs)

  subscribedTo: (subscriberId, path) ->
    for p, re of @_subscriberPatternSubs[subscriberId]
      return true if re.test path
    return false


subsMatchPath = (subs, path) ->
  for subscriberId, re of subs
    return re.test path
