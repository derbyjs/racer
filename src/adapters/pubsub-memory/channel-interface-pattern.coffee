{regExp: pathRegExp} = require '../../path'
{hasKeys} = require '../../util'

module.exports = patternInterface = (pubSub) ->
  # patternString -> {re: RegExp, subscribers: (subscriberId -> true)}
  forwardIndex = {}

  # subscriberId -> (patternString -> true)
  reverseIndex = {}

  intf = {}

  intf.subscribe = (subscriberId, pattern, ackCb) ->
    (reverseIndex[subscriberId] ||= {})[pattern] = true

    unless subsForPattern = forwardIndex[pattern]
      subsForPattern = forwardIndex[pattern] =
        re: pathRegExp pattern
        subscribers: {}
    subsForPattern.subscribers[subscriberId] = true
    ackCb? null

  intf.publish = (msg) ->
    {type, params} = msg
    switch type
      when 'txn', 'ot'
        for pattern, {re, subscribers} of forwardIndex
          continue unless re.test params.channel
          for subscriberId of subscribers
            pubSub.emit type, subscriberId, params.data

  intf.unsubscribe = (subscriberId, pattern, ackCb) ->
    if typeof pattern isnt 'string'
      ackCb = pattern

      # Clean up forward index
      for pattern of reverseIndex[subscriberId]
        {subscribers} = forwardIndex[pattern]
        delete subscribers[subscriberId]
        unless hasKeys subscribers
          delete forwardIndex[pattern]

      # Clean up reverseIndex
      delete reverseIndex[subscriberId]
    else
      # Clean up reverseIndex
      unless patterns = reverseIndex[subscriberId]
        # If the subscriberId was never subscribed, do nothing
        return ackCb? null 
      delete patterns[pattern]
      unless hasKeys patterns
        delete reverseIndex[subscriberId]

      # Clean up forward index
      {subscribers} = forwardIndex[pattern]
      delete subscribers[subscriberId]
      unless hasKeys subscribers
        delete forwardIndex[pattern]

    ackCb? null

  intf.hasSubscriptions = (subscriberId) ->
    return subscriberId of reverseIndex

  intf.subscribedTo = (subscriberId, pattern) ->
    return false unless patterns = reverseIndex[subscriberId]
    return pattern of patterns

  return intf
