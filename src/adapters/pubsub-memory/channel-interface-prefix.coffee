patternInterface = require './channel-interface-pattern'

module.exports = prefixInterface = (pubSub) ->
  patternApi = patternInterface pubSub
  return {
    subscribe: (subscriberId, prefix, ackCb) ->
      patternApi.subscribe subscriberId, prefix, ackCb

    publish: (msg) ->
      patternApi.publish msg

    unsubscribe: (subscriberId, prefix, ackCb) ->
      patternApi.unsubscribe subscriberId, prefix, ackCb

    hasSubscriptions: (subscriberId) ->
      patternApi.hasSubscriptions subscriberId

    subscribedTo: (subscriberId, prefix) ->
      patternApi.subscribedTo subscriberId, prefix
  }
