TxnApplier = require 'TxnApplier'
should = require 'should'


module.exports =
  # For Store
  'should not apply transactions that rely on a transaction that has not yet been added to the txn applier': (done) ->
    txnApplier = new TxnApplier
    txnApplier.PERIOD = 500
    txnApplier.serializingIndex = 1
    applied = []
    txnApplier.waitForDependencies = ->
      setInterval ->
        txnApplier.flushValidPending()
        applied.should.eql []
        clearInterval txnApplier.waiter
        txnApplier.waiter = null
        done()
      , txnApplier.PERIOD
    txnApplier.applyTxn = (txn) ->
      applied.push txn

    txnApplier.add 2, [2, '0.1', 'set', 'foo', 'bar']

  'should immediately apply a transaction that matches the next serialization index': (done) ->
    txnApplier = new TxnApplier
    txnApplier.PERIOD = 500
    txnApplier.serializingIndex = 1
    applied = []
    txn = [1, '0.1', 'set', 'foo', 'bar']
    txnApplier.waitForDependencies = ->
    txnApplier.applyTxn = (txn) ->
      applied.push txn

    txnApplier.add 1, txn
    applied.should.eql [txn]
    done()

  'should queue up transactions that have dependencies and then apply them once it receives those dependencies': (done) ->
    txnApplier = new TxnApplier
    txnApplier.PERIOD = 500
    txnApplier.serializingIndex = 1
    applied = []
    counter = 0
    txn1 = [1, '0.1', 'set', 'foo', 'bar']
    txn2 = [2, '0.1', 'set', 'foo', 'bart']
    txn3 = [3, '0.1', 'set', 'foo', 'muni']
    txnApplier.waitForDependencies = ->
      setInterval ->
        counter++
        txnApplier.flushValidPending()
        if counter == 1 || counter == 2
          applied.should.eql []
        if counter == 3
          applied.should.eql [txn1, txn2, txn3]
          clearInterval txnApplier.waiter
          txnApplier.waiter = null
          done()
      , txnApplier.PERIOD
    txnApplier.applyTxn = (txn) ->
      applied.push txn

    txnApplier.add 3, txn3
    setTimeout ->
      txnApplier.add 2, txn2
    , txnApplier.PERIOD + 100
    setTimeout ->
      txnApplier.add 1, txn1
    , txnApplier.PERIOD * 2 + 100

  # TODO Add tests for clear(), stopWaitingForDependencies(), and flushValidPending()
