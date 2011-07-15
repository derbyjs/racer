should = require 'should'
Store = require 'Store'

store = new Store

finishAll = false
module.exports =
  setup: (done) ->
    store.flush done
  teardown: (done) ->
    if finishAll
      clearInterval store._pendingInterval
      store._redisClient.end()
      return done()
    store.flush done

  finishAll: (done) -> finishAll = true; done()

  ## !! PLACE ALL TESTS BEFORE finishAll !! ##
