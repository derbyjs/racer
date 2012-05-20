patternInterface = require './channel-interface-pattern'
prefixInterface = require './channel-interface-prefix'
stringInterface = require './channel-interface-string'
queryInterface = require './channel-interface-query'

exports = module.exports = (racer, opts = {}) ->
  racer.mixin
    type: 'Store'
    events:
      init: (store) ->
        pubSub = store._pubSub
        pubSub.addChannelInterface 'pattern', patternInterface pubSub
        pubSub.addChannelInterface 'prefix', prefixInterface pubSub
        pubSub.addChannelInterface 'string', stringInterface pubSub
        pubSub.addChannelInterface 'query', queryInterface pubSub, store

  return

exports.useWith = server: true, browser: false
exports.decorate = 'racer'
