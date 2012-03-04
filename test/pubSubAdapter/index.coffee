{adapter} = require '../util/store'

module.exports = adapter 'pubSub', (run) ->

  run 'server-side model subscription', require './subscribe'
