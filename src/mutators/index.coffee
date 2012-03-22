mixinModel = require './mutators.Model'
mixinStore = __dirname + '/mutators.Store'

exports = module.exports = (racer) ->
  racer.mixin mixinModel, mixinStore

exports.useWith = server: true, browser: true
