Serializer = require '../src/Serializer'
should = require 'should'

describe 'Serializer', ->
  
  it 'should not apply a transaction greater than the next index', ->
    applied = []
    txnApplier = new Serializer
      withEach: (txn) -> applied.push txn
    
    txnApplier.add [2, '0.1', 'set', 'foo', 'bar'], 2
    applied.should.eql []
  
  it 'should immediately apply a transaction that matches the next index', ->
    applied = []
    txnApplier = new Serializer
      withEach: (txn) -> applied.push txn
    
    txn = [1, '0.1', 'set', 'foo', 'bar']
    txnApplier.add txn, 1
    applied.should.eql [txn]
  
  it 'out of order transactions should be applied in the correct order', ->
    applied = []
    txnApplier = new Serializer
      withEach: (txn) -> applied.push txn
    
    txn1 = [1, '0.1', 'set', 'foo', 'bar']
    txn2 = [2, '0.1', 'set', 'foo', 'bart']
    txn3 = [3, '0.1', 'set', 'foo', 'muni']
    txnApplier.add txn3, 3
    txnApplier.add txn2, 2
    txnApplier.add txn1, 1
    applied.should.eql [txn1, txn2, txn3]

# TODO: Add tests for timeout waiter, setIndex, clearPending
