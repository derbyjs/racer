mixinModel = require './mutators.Model'
mixinStore = __dirname + '/mutators.Store'

module.exports = (racer) ->
  racer.mixin mixinModel, mixinStore
