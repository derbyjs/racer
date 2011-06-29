# Tests for Op(erations)
should = require 'should'
txn = require 'server/txn'

# transaction object literal
transaction = [baseVer = 2, txnId = '4.0', method = 'set', path = 'count', 1]

module.exports =
  # Properties

  'it should be able to access the baseVer': ->
    txn.ver.server(transaction).should.equal(2)
    txn.base(transaction).should.equal(2)

  'it should be able to access the transaction id': ->
    txn.id(transaction).should.equal '4.0'

  'it should be able to access the method': ->
    txn.method(transaction).should.equal('set')

  'it should be able to access the path': ->
    txn.path(transaction).should.equal('count')
    
  'it should be able to access the arguments': ->
    txn.args(transaction).should.eql([1])

  'it should be able to deduce the clientId from the transcation object literal (transaction)': ->
    txn.clientId(transaction).should.equal '4'

  'it should be able to deduce the client version from the transaction object literal': ->
    txn.ver.client(transaction).should.equal 0

  # Evaluating (but not applying) transactions

  # Applying transactions

  # Path Conflict Detection

  '2 paths that are not string equivalent where 1 is not a substring of the other, should have noconflict': ->
    txn.pathConflict('abc', 'def').should.be.false
    txn.pathConflict('def', 'abc').should.be.false # symmetric

  '2 paths that are not string equivalent but 1 is a substring of the other, should have a conflict': ->
    # nested paths
    txn.pathConflict('abc', 'abc.def').should.be.true
    txn.pathConflict('abc.def', 'abc').should.be.true # symmetric

  '2 paths that are string equivalent should have a conflict': ->
    txn.pathConflict('abc', 'abc').should.be.true

  # Transaction Conflict Detection
  
  '2 txns should conflict iff they update the same path to different values and are from different clients': ->
    txnOne   = [0, '0.0', 'set', 'count', 0]
    txnTwo   = [0, '1.0', 'set', 'count', 1]
    txnThree = [0, '0.0', 'set', 'count', 1]
    txnFour  = [0, '2.0', 'set', 'name', 'drago']

    txn.isConflict(txnOne, txnTwo).should.be.true
    txn.isConflict(txnOne, txnThree).should.be.false # Because same client
    txn.isConflict(txnTwo, txnThree).should.be.false # Because same value
    txn.isConflict(txnTwo, txnFour).should.be.false # Because not same path

  "a txn should be able to detect a conflict with a given both (1) path/value and (2) the server version at the time of that path/value's last update": ->
    txnOne = [1, '1.0', 'set', 'count', 0]
    txn.isConflict(txnOne, 0, 2).should.be.false # Because shares same value
    txn.isConflict(txnOne, 1, 2).should.be.true  # Because conflicting values and precedes last update version
    txn.isConflict(txnOne, 1, 1).should.be.true  # Because conflicting values and equals last update version
    txn.isConflict(txnOne, 1, 0).should.be.false # Because txn base > last updated base

  # TODO If 1 path is an ancestor of another path
