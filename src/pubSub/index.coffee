LiveQuery = require './LiveQuery'
Query = require './Query'
mixinModel = require './pubSub.Model'
mixinStore = __dirname + '/pubSub.Store'

exports = module.exports = (racer) ->
  racer.LiveQuery = LiveQuery
  racer.Query = Query
  racer.mixin mixinModel, mixinStore

exports.useWith = server: true, browser: true
