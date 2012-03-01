{run} = require '../util/store'
racer = require '../../src/racer'

module.exports = (options, plugin) -> describe "#{options.type} db adapter", ->
  racer.use plugin  if plugin

  run 'store mutators', {db: options}, require './storeMutators'
