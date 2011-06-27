# Tests for Op(erations)
should = require 'should'
Txn = require '../lib/txn'
# Txn.prototype.clientId = '0'

module.exports =
  # Properties

  'it should have a transaction id equivalent to the "{clientId}.#{numOpsGenerated}"' ->
    txn = new Txn('0', { targ: 'count', type: 'set', val: 0 })
    txn.id.should.equal '0.2'

  'should be able to instantiate an id without passing clientId, if clientId is in the prototype' ->
    Txn.prototype.clientId = '0'
    txn = new Txn { targ: 'count', type: 'set', val: 0 }
    txn.clientId.should.equal '0'
    delete Txn.prototype.clientId

  'should not be able to instantiate an id without passing clientId, if clientId id not in the prototype' ->
    try {
      new Txn { targ: 'count', type: 'set', val: 0 }
    } catch (e) {
      e.should.be.an.instanceof(Error)
    }

  # Wire message protocol

  'it should be able to serialize to JSON': ->
    txn = new Txn('client0', { targ: 'count', type: 'set', val: 0 })
    txn.toJSON().should.eql {
      c: ['0.1', 1] # Vector clock
      k: 'count'
      t: 'set'
      v: 0
    }

  'it should be able to de-serialize from JSON': ->
    txn = Txn.fromJSON {
      c: ['0.1', 2]
      k: 'count'
      t: 'set'
      v: 0
    }
    txn.should.be.an.instanceof Txn

    txn.client.should.equal 0

    txn.ver.client.should.equal 1
    txn.ver.server.should.equal 2

    txn.targ.should.equal 'count'
    txn.type.should.equal 'set'
    txn.val.should.equal 0

  # Comparing transactions

  # Conflict detection
