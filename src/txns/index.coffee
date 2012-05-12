mixinModel = require './txns.Model'
mixinStore = __dirname + '/txns.Store'

exports = module.exports = (racer) ->
  racer.mixin mixinModel, mixinStore

exports.useWith = server: true, browser: true
