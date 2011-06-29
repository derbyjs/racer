should = require 'should'
stm = require 'server/stm'

stm.connect()
module.exports =
  setup: (done) ->
    stm.client.flushdb (err) ->
      throw err if err
      done()
  teardown: (done) ->
    stm.client.flushdb (err) ->
      throw err if err
      done()

  '2 conflicting transactions should callback for conflict resolution': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'red']
    stm.attempt txnOne, (err) ->
      should.strictEqual null, err
    stm.attempt txnTwo, (err) ->
      err.should.be.an.instanceof Error
      done()

  '2 non-conflicting transactions should be fine': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '1.1', 'set', 'color', 'red']
    stm.attempt txnOne, (err) ->
      should.strictEqual null, err
    stm.attempt txnTwo, (err) ->
      should.strictEqual null, err
      done()
  'finishAll': (done) ->
    stm.client.end()
    done()
