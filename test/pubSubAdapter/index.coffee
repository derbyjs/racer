{adapter} = require '../util/store'

module.exports = adapter 'pubSub', (run) ->

  run 'pubsub adapter methods', require './methods'
