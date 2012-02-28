redis = require 'redis'
{expect} = require './util'
racer = require '../src/racer'
transaction = require '../src/transaction'

describe 'Store', ->

  store = null
  redisClient = redis.createClient()

  after ->
    redisClient.end()

  # TODO: Run tests for all store modes
  beforeEach (done) ->
    store = racer.createStore()
    store.flush done

  afterEach (done) ->
    store.flush ->
      store.disconnect()
      done()

  it 'flush should delete everything in the adapter and redisClient', (done) ->
    callbackCount = 0
    store.set 'color', 'green', 1, ->
      store.get 'color', (err, value) ->
        expect(value).to.equal 'green'
        redisClient.keys '*', (err, value) ->
          # Note that flush calls redisInfo.onStart immediately after
          # flushing, so the key 'starts' should exist
          expect(value).to.eql ['txns', 'ver', 'starts']
          store.flush (err) ->
            expect(err).to.be.null()
            expect(++callbackCount).to.eql 1
            store.get 'color', (err, value) ->
              expect(value).to.equal undefined
              redisClient.keys '*', (err, value) ->
                if ~value.indexOf 'clientClock'
                  # Once again, 'clientClock' and 'starts' should exist after the flush
                  expect(value).to.eql ['clientClock', 'starts']
                else
                  expect(value).to.eql ['starts']
                done()

  it 'flush should return an error if the adapter fails to flush', (done) ->
    callbackCount = 0
    store._db.flush = (callback) -> callback new Error
    store.flush (err) ->
      expect(err).to.be.an Error
      expect(++callbackCount).to.eql 1
      done()

  it 'flush should return an error if the journal fails to flush', (done) ->
    callbackCount = 0
    store._journal.flush = (callback) -> callback new Error
    store.flush (err) ->
      expect(err).to.be.an Error
      expect(++callbackCount).to.eql 1
      done()

  it 'flush should return an error if the adapter and journal fail to flush', (done) ->
    callbackCount = 0
    store._db.flush = (callback) -> callback new Error
    store._journal.flush = (callback) -> callback new Error
    store.flush (err) ->
      expect(err).to.be.an Error
      expect(++callbackCount).to.eql 1
      done()

  # TODO: Move to subscribe tests
  it 'subscribe should only copy the appropriate properties', (done) ->
    tests =
      '': {a: {b: 1, c: 2, d: [1, 2]}, e: {c: 7}}
      'a': {a: {b: 1, c: 2, d: [1, 2]}}
      'a.b': {a: {b: 1}}
      'a.d': {a: {d: [1, 2]}}
      '*.c': {a: {c: 2}, e: {c: 7}}

    patterns = Object.keys tests
    count = patterns.length
    finish = -> done() unless --count
    store.set 'a', {b: 1, c: 2, d: [1, 2]}, null, ->
      store.set 'e', {c: 7}, null, ->
        patterns.forEach (pattern) ->
          expected = tests[pattern]
          model = store.createModel()
          model.subscribe pattern, ->
            expect(model.get()).to.specEql expected
            finish()

  it 'store._commit should apply transactions in order', (done) ->
    idIn = []
    idOut = []
    for i in [0..9]
      idIn.push id = "1.#{i}"
      txn = transaction.create(base: 0, id: id, method: 'set', args: ['stuff', 0])
      store._commit txn, (err, txn) ->
        idOut.push transaction.id txn
        finish() if idOut.length is 10
    finish = ->
      expect(idIn).to.eql idOut
      done()

  # TODO tests:
  # 'should, upon socket.io disconnect, remove the socket from the sockets._byClientID index'
