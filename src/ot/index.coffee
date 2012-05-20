mixinModel = require './ot.Model'
mixinStore = __dirname + '/ot.Store'

exports = module.exports = (racer) ->
  racer.mixin mixinModel, mixinStore

exports.useWith = browser: true, server: true
exports.decorate = 'racer';
