mixinModel = require './txns.Model'
mixinStore = __dirname + '/txns.Store'

module.exports = (racer) ->
  racer.mixin mixinModel, mixinStore
