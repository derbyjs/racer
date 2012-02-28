mixinModel = require './ot.Model'
mixinStore = __dirname + '/ot.Store'

module.exports = (racer) ->
  racer.mixin mixinModel, mixinStore
