# Tests for Op(erations)
should = require 'should'
txn = require 'server/txn'

# transaction object literal
tol = [baseVer = 2, txnId = '4.0', method = 'set', path = 'count', 1]

module.exports =
  # Properties

  'it should be able to access the baseVer': ->
    txn.ver.server(tol).should.equal(2)
    txn.base(tol).should.equal(2)

  'it should be able to access the transaction id': ->
    txn.id(tol).should.equal '4.0'

  'it should be able to access the method': ->
    txn.method(tol).should.equal('set')

  'it should be able to access the path': ->
    txn.path(tol).should.equal('count')
    
  'it should be able to access the arguments': ->
    txn.args(tol).should.eql([1])

  'it should be able to deduce the clientId from the transcation object literal (tol)': ->
    txn.clientId(tol).should.equal '4'

  'it should be able to deduce the client version from the transaction object literal': ->
    txn.ver.client(tol).should.equal 0

  # Evaluating (but not applying) transactions

  # Applying transactions

  # Conflict detection
  
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
