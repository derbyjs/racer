mixinModel = require './pubSub.Model'
mixinStore = __dirname + '/pubSub.Store'

module.exports = (racer) ->
  racer.mixin mixinModel, mixinStore
