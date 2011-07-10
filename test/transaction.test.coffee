# Tests for Op(erations)
should = require 'should'
transaction = require 'transaction'

# transaction object literal
txn = [baseVer = 2, txnId = '4.0', method = 'set', path = 'count', 1]

module.exports =
  # Properties

  'it should be able to access the baseVer': ->
    transaction.base(txn).should.equal 2

  'it should be able to access the transaction id': ->
    transaction.id(txn).should.equal '4.0'

  'it should be able to access the method': ->
    transaction.method(txn).should.equal 'set'

  'it should be able to access the path': ->
    transaction.path(txn).should.equal 'count'
    
  'it should be able to access the arguments': ->
    transaction.args(txn).should.eql [1]

  # Evaluating (but not applying) transactions

  # Applying transactions

  # Path Conflict Detection

  'Paths where neither is a sub-path of the other should not conflict': ->
    transaction.pathConflict('abc', 'def').should.be.false
    transaction.pathConflict('def', 'abc').should.be.false # symmetric
    transaction.pathConflict('abc.de', 'abc.def').should.be.false
    transaction.pathConflict('abc.def', 'abc.de').should.be.false # symmetric

  'Paths where one is a sub-path of the other should conflict': ->
    transaction.pathConflict('abc', 'abc.def').should.be.true
    transaction.pathConflict('abc.def', 'abc').should.be.true # symmetric
    transaction.pathConflict('abc', 'abc').should.be.true

  # Transaction Conflict Detection
  
  'test conflict detection between transactions': ->
    txn1 = [0, '1.0', 'set', 'count', 1]
    txn2 = [0, '0.0', 'set', 'count', 0]
    txn3 = [0, '0.0', 'del', 'count', 1]
    txn4 = [0, '0.0', 'set', 'count', 1, 0]
    txn5 = [0, '0.1', 'set', 'count', 1]
    txn6 = [0, '0.1', 'set', 'name', 'drago']
    
    txn7 = [0, '1.0', 'set', 'obj.nested', 0]
    txn8 = [0, '2.0', 'set', 'obj.nested.a', 0]

    transaction.conflict(txn1, txn2).should.be.true # Different arguments
    transaction.conflict(txn1, txn3).should.be.true # Different method
    transaction.conflict(txn1, txn4).should.be.true # Different number of arguments
    
    transaction.conflict(txn2, txn5).should.be.true # Same client, wrong order
    transaction.conflict(txn5, txn2).should.be.false # Same client, correct order
    
    transaction.conflict(txn1, txn5).should.be.false # Same method, path, and arguments
    transaction.conflict(txn1, txn6).should.be.false # Non-conflicting paths

    transaction.conflict(txn7, txn8).should.be.true # Conflicting nested paths
    transaction.conflict(txn8, txn7).should.be.true # Conflicting nested paths
