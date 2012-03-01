{EventEmitter} = require 'events'

module.exports = (racer) ->
  racer.adapters.pubSub.None = PubSubNone

PubSubNone = ->
  return

PubSubNone:: =
  __proto__: EventEmitter::

  publish: ->

  subscribe: ->
    throw new Error 'subscribe is not supported without a pubSub adapter'

  unsubscribe: ->

  hasSubscriptions: -> false

  subscribedTo: -> false
