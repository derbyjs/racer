should = require 'should'
Store = require 'Store'

store = null
module.exports =
  setup: (done) ->
    store = new Store
    store.flush done
  teardown: (done) ->
    store.flush ->
      clearInterval store._pendingInterval
      store._redisClient.end()
      done()
  
  'flush should delete everything in the adapter and redisClient': (done) ->
    callbackCount = 0
    store._adapter.set 'color', 'green', 1, ->
      store._redisClient.set 'color', 'green', ->
        store._adapter.get null, (err, value) ->
          value.should.eql color: 'green'
          store._redisClient.keys '*', (err, value) ->
            value.should.eql ['color']
            store.flush (err) ->
              should.equal null, err
              (++callbackCount).should.eql 1
              store._adapter.get null, (err, value) ->
                value.should.eql {}
                store._redisClient.keys '*', (err, value) ->
                  value.should.eql []
                  done()

  'flush should return an error if the adapter fails to flush': (done) ->
    callbackCount = 0
    store._adapter.flush = (callback) -> callback new Error
    store.flush (err) ->
      err.should.be.instanceof Error
      (++callbackCount).should.eql 1
      done()
  
  'flush should return an error if the redisClient fails to flush': (done) ->
    callbackCount = 0
    store._redisClient.flushdb = (callback) -> callback new Error
    store.flush (err) ->
      err.should.be.instanceof Error
      (++callbackCount).should.eql 1
      done()
  
  'flush should return an error if the adapter and redisClient fail to flush': (done) ->
    callbackCount = 0
    store._adapter.flush = (callback) -> callback new Error
    store._redisClient.flushdb = (callback) -> callback new Error
    store.flush (err) ->
      err.should.be.instanceof Error
      (++callbackCount).should.eql 1
      done()
  
  