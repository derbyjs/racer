should = require 'should'
Store = require 'Store'
redis = require 'redis'
transaction = require 'transaction'

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
  
  'flush should delete everything in the adapter and redisClient': (done) ->
    callbackCount = 0
    store._adapter.set 'color', 'green', 1, ->
      store._redisClient.set 'color', 'green', ->
        store._adapter.get null, (err, value) ->
          value.should.eql color: 'green'
          store._redisClient.keys '*', (err, value) ->
            # Note that flush calls redisInfo.onStart immediately after
            # flushing, so the key 'starts' should exist
            value.should.eql ['color', 'starts']
            store.flush (err) ->
              should.equal null, err
              (++callbackCount).should.eql 1
              store._adapter.get null, (err, value) ->
                value.should.eql {}
                store._redisClient.keys '*', (err, value) ->
                  # Once again, the key starts should exist after the flush
                  value.should.eql ['starts']
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

  'test that subscribe only copies the appropriate properties': (done) ->
    count = 6
    finish = -> done() unless --count
    store.set 'a', {b: 1, c: 2, d: [1, 2]}, null, ->
      store.set 'e', {c: 7}, null, ->

        model0 = store.createModel()
        model0.subscribe 'a', ->
          model0.get().should.eql a: {}
          finish()

        model1 = store.createModel()
        model1.subscribe 'a.b', ->
          model1.get().should.eql a: {b: 1}
          finish()

        model2 = store.createModel()
        model2.subscribe 'a.d', ->
          model2.get().should.eql a: {d: []}
          finish()

        # TODO: Fix this case. It is pretty nasty because arrays could be
        # embedded anywhere along the path
        # model3 = store.createModel()
        # model3.subscribe 'a.d.1', (err, model) ->
        #   model3.get().should.eql a: {d: [undefined, 1]}
        #   finish()

        model4 = store.createModel()
        model4.subscribe '**', ->
          model4.get().should.eql a: {b: 1, c: 2, d: [1, 2]}, e: {c: 7}
          finish()

        model5 = store.createModel()
        model5.subscribe 'a.**', ->
          model5.get().should.eql a: {b: 1, c: 2, d: [1, 2]}
          finish()

        model6 = store.createModel()
        model6.subscribe '*', ->
          model6.get().should.eql a: {}, e: {}
          finish()

        # model7 = store.createModel()
        # model7.subscribe 'a.*', ->
        #   model7.get().should.eql a: {b: 1, c: 2, d: []}
        #   finish()

        # model8 = store.createModel()
        # model8.subscribe '*.c', ->
        #   model8.get().should.eql a: {c: 2}, e: {c: 7}
        #   finish()

  'store._commit should apply transactions in order': (done) ->
    idIn = []
    idOut = []
    for i in [0..9]
      idIn.push id = "1.#{i}"
      txn = transaction.create(base: 0, id: id, method: 'set', args: ['stuff', 0])
      store._commit txn, (err, txn) ->
        idOut.push transaction.id txn
        finish() if idOut.length is 10
    finish = ->
      idIn.should.eql idOut
      done()
  
  # TODO tests:
  # 'should, upon socket.io disconnect, remove the socket from the sockets._byClientID index'
