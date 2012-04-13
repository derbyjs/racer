{regExp: pathRegExp} = require '../../path'
{hasKeys} = require '../../util'

module.exports = stringInterface = (pubSub) ->
  # forwardIndex comes in handy for efficient publish
  #
  # string -> (subscriberId -> RegExp)
  forwardIndex = {}

  # reverseIndex comes in handy for efficient cleanup
  # in unsubscribe
  #
  # subscriberId -> (string -> true)
  reverseIndex = {}

  intf = {}

  intf.subscribe = (subscriberId, str, ackCb) ->
    subscribers = forwardIndex[str] ||= {}
    subscribers[subscriberId] = true

    strings = reverseIndex[subscriberId] ||= {}
    strings[str] = true

    ackCb? null

  intf.publish = ({type, params}) ->
    switch type
      when 'direct'
        if subscribers = forwardIndex[params.channel]
          for subscriberId of subscribers
            pubSub.emit 'direct', subscriberId, params.data
      when 'txn'
        if subscribers = forwardIndex[params.channel]
          for subscriberId of subscribers
            pubSub.emit 'txn', subscriberId, params.data
      when 'addDoc'
        if subscribers = forwardIndex[params.channel]
          for subscriberId of subscribers
            pubSub.emit 'addDoc', subscriberId, params.data
      when 'rmDoc'
        if subscribers = forwardIndex[params.channel]
          for subscriberId of subscribers
            pubSub.emit 'rmDoc', subscriberId, params.data
    return

  intf.unsubscribe = (subscriberId, str, ackCb) ->
    if typeof str isnt 'string'
      # Detects fn signature: unsubscribe(subscriberId, ackCb)
      # This fn sig means unsubscribe the subscriberId from everything
      ackCb = str

      # Clean up forward index
      for str of reverseIndex[subscriberId]
        subscribers = forwardIndex[str]
        delete subscribers[subscriberId]
        unless hasKeys subscribers
          delete forwardIndex[str]

      # Clean up reverse index
      delete reverseIndex[subscriberId]
    else
      # Clean up reverse index
      strings = reverseIndex[subscriberId]
      delete strings[str]
      unless hasKeys strings
        delete reverseIndex[subscriberId]

      # Clean up forwardIndex
      subscribers = forwardIndex[str]
      delete subscribers[subscriberId]
      unless hasKeys subscribers
        delete forwardIndex[str]

    ackCb? null

  intf.hasSubscriptions = (subscriberId) ->
    return subscriberId of reverseIndex

  intf.subscribedTo = (subscriberId, str) ->
    return false unless strings = reverseIndex[subscriberId]
    return str of strings

  return intf
