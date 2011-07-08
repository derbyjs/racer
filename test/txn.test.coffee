# Tests for Op(erations)
should = require 'should'
txn = require 'server/txn'

# transaction object literal
transaction = [baseVer = 2, txnId = '4.0', method = 'set', path = 'count', 1]

module.exports =
  # Properties

  'it should be able to access the baseVer': ->
    txn.base(transaction).should.equal 2

  'it should be able to access the transaction id': ->
    txn.id(transaction).should.equal '4.0'

  'it should be able to access the method': ->
    txn.method(transaction).should.equal 'set'

  'it should be able to access the path': ->
    txn.path(transaction).should.equal 'count'
    
  'it should be able to access the arguments': ->
    txn.args(transaction).should.eql [1]

  # Evaluating (but not applying) transactions

  # Applying transactions

  # Path Conflict Detection

  'Paths where neither is a sub-path of the other should not conflict': ->
    txn.pathConflict('abc', 'def').should.be.false
    txn.pathConflict('def', 'abc').should.be.false # symmetric
    txn.pathConflict('abc.de', 'abc.def').should.be.false
    txn.pathConflict('abc.def', 'abc.de').should.be.false # symmetric

  'Paths where one is a sub-path of the other should conflict': ->
    txn.pathConflict('abc', 'abc.def').should.be.true
    txn.pathConflict('abc.def', 'abc').should.be.true # symmetric
    txn.pathConflict('abc', 'abc').should.be.true

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

    txn.conflict(txn1, txn2).should.be.true # Different arguments
    txn.conflict(txn1, txn3).should.be.true # Different method
    txn.conflict(txn1, txn4).should.be.true # Different number of arguments
    
    txn.conflict(txn2, txn5).should.be.true # Same client, wrong order
    txn.conflict(txn5, txn2).should.be.false # Same client, correct order
    
    txn.conflict(txn1, txn5).should.be.false # Same method, path, and arguments
    txn.conflict(txn1, txn6).should.be.false # Non-conflicting paths

    txn.conflict(txn7, txn8).should.be.true # Conflicting nested paths
    txn.conflict(txn8, txn7).should.be.true # Conflicting nested paths
