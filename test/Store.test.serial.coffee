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
      {_subscribeClient, _publishClient} = store._pubsub._adapter
      _subscribeClient.end()
      _publishClient.end()
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

  'subscribe should create a new model if one is not passed in': (done) ->
    store.subscribe 'a', 'b', (err, modelA) ->
      should.equal null, err
      store.subscribe 'c', (err, modelB) ->
        modelA.should.not.eql modelB
        done()

  'subscribe should use the passed in model if present': (done) ->
    store.subscribe 'a', 'b', (err, modelA) ->
      should.equal null, err
      store.subscribe modelA, 'c', (err, modelB) ->
        modelA.should.equal modelB
        done()

  # TODO tests:
  # 'should, upon socket.io disconnect, remove the socket from the sockets._byClientID index'
