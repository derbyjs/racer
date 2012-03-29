{EventEmitter} = require 'events'

exports = module.exports = (racer) ->
  racer.registerAdapter 'pubSub', 'None', PubSubNone

exports.useWith = server: true, browser: false

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
