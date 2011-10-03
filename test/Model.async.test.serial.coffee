should = require 'should'
Store = require 'Store'

store = null
module.exports =
  setup: (done) ->
    store = new Store
    store.flush done
  teardown: (done) ->
    store.flush ->
      store._redisClient.end()
      store._subClient.end()
      store._txnSubClient.end()
      done()

  'test model.async.retry': (done) ->
    model = store.createModel()
    incr = (path, callback) ->
      model.async.retry (atomic) ->
        atomic.get path, (count = 0) ->
          atomic.set path, ++count
      , callback
    i = 5
    cbCount = 5
    while i--
      incr 'count', ->
        unless --cbCount
          setTimeout ->
            model.async.get 'count', (err, value) ->
              value.should.eql 5
              done()
          , 50
