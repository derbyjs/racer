{EventEmitter} = require 'events'
{finishAfter} = require '../util/async'

isPattern = (x) -> -1 != x.indexOf '*'

module.exports = PubSub = ->
  EventEmitter.call this
  @_channelTypes =
    pattern: (x) -> typeof x is 'string' && isPattern x
    prefix: (x) -> typeof x is 'string'
    string: (x) -> typeof x is 'string'
    query: (x) -> x.isQuery

  @string = Object.create @,
    _channelTypes:
      value: string: @_channelTypes.string

  @prefix = Object.create @,
    _channelTypes:
      value: prefix: @_channelTypes.prefix

  @pattern = Object.create @,
    _channelTypes:
      value: pattern: @_channelTypes.pattern

  @query = Object.create @,
    _channelTypes:
      value: query: @_channelTypes.query

  return

PubSub:: =
  __proto__: EventEmitter::

  subscribe: (subscriberId, channels, callback) ->
    numChannels = channels.length
    if numChannels > 1
      callback = finishAfter numChannels, callback
    for channel in channels
      unless type = @_channelType channel
        throw new Error "Channel #{channel} doesn't match a channel type"
      type.subscribe subscriberId, channel, callback

    return this

  publish: (message, meta) ->
    for _, type of @_channelTypes
      type.publish message, meta
    return

  unsubscribe: (subscriberId, channels, callback) ->
    unless numChannels = channels?.length
      for _, type of @_channelTypes
        type.unsubscribe subscriberId, callback
    else
      if numChannels > 1
        callback = finishAfter numChannels, callback
      for channel in channels
        unless type = @_channelType channel
          throw new Error "Channel #{channel} doesn't match a channel type"
        type.unsubscribe subscriberId, channel, callback

    return this

  hasSubscriptions: (subscriberId) ->
    for _, type of @_channelTypes
      return true if type.hasSubscriptions subscriberId
    return false

  subscribedTo: (subscriberId, channel) ->
    return @_channelType(channel).subscribedTo subscriberId, channel

  addChannelInterface: (channelType, intf) ->
    type = @_channelTypes[channelType]
    for name, fn of intf
      type[name] = fn
    return

  _channelType: (x) ->
    for _, type of @_channelTypes
      return type if type x
    return

  disconnect: ->
    @emit 'disconnect'
