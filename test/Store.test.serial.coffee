should = require 'should'
Store = require 'Store'

store = new Store

module.exports =
  setup: (done) ->
    store.flush done

  teardown: (done) ->
    store.flush done
