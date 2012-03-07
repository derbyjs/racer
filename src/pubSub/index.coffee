LiveQuery = require './LiveQuery'
Query = require './Query'
mixinModel = require './pubSub.Model'
mixinStore = __dirname + '/pubSub.Store'

module.exports = (racer) ->
  racer.LiveQuery = LiveQuery
  racer.Query = Query
  racer.mixin mixinModel, mixinStore
