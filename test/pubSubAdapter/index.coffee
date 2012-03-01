{expect} = require './index'
{run} = require './store'
transaction = require '../../src/transaction'
racer = require '../../src/racer'

module.exports = (options, plugin) -> describe "#{options.type} pubSub adapter", ->
  racer.use plugin  if plugin

  run '', {mode: 'stm', pubSub: options}, (getStore) ->

    it '', (done) ->
      
