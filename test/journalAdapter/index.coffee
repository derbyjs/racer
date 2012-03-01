{run} = require '../util/store'
racer = require '../../src/racer'

module.exports = (options, plugin) -> describe "#{options.type} journal adapter", ->
  racer.use plugin  if plugin

  run 'STM commit', {mode: 'stm', journal: options}, require './stmCommit'
