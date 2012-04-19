mixinModel = require './pubSub.Model'
mixinStore = __dirname + '/pubSub.Store'

exports = module.exports = (racer) ->
  racer.mixin mixinModel, mixinStore

exports.useWith = server: true, browser: true
