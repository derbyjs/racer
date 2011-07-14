should = require 'should'
Store = require 'Store'

store = new Store

module.exports =
  setup: (done) ->
    store.flush (err) ->
      throw err if err
      done()
  teardown: (done) ->
    store.flush (err) ->
      throw err if err
      done()

  finishAll: (done) ->
    clearInterval store._pendingInterval
    store._redisClient.end()
    done()

  ## !!!! PLACE ALL TESTS BEFORE finishAll
