patternInterface = require './channel-interface-pattern'
prefixInterface = require './channel-interface-prefix'
stringInterface = require './channel-interface-string'
queryInterface = require './channel-interface-query'

module.exports = (racer, opts = {}) ->
  racer.mixin
    type: 'Store'
    events:
      init: (store) ->
        pubSub = store._pubSub
        pubSub.defChannelInterface 'pattern', patternInterface pubSub

        pubSub.defChannelInterface 'prefix', prefixInterface pubSub

        pubSub.defChannelInterface 'string', stringInterface pubSub

        pubSub.defChannelInterface 'query', queryInterface pubSub, store

  return
