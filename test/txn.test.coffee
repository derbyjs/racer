# Tests for Op(erations)
should = require 'should'
Txn = require '../lib/txn'
Txn.prototype.ver = { client: 4, server: 100 }
_clientVer = 4

module.exports =
  # Properties

  'instantiating a new Txn should increment the client version': ->
    txn = new Txn '0', { targ: 'count', type: 'set', val: 0 }
    Txn.prototype.ver.client.should.equal ++_clientVer

  "instantiating a new Txn should only increment the prototype client ver, not prior instantiated Txn's client ver" ->
    txnOne = new Txn '0', { targ: 'count', type: 'set', val: 0 }
    ++_clientVer
    txnTwo = new Txn '0', { targ: 'count', type: 'set', val: 1 }
    ++_clientVer
    Txn.prototype.ver.client.should.equal _clientVer
    txnTwo.ver.client.should.equal _clientVer
    txnOne.ver.client.should.equal _clientVer-1

  'it should have a transaction id equivalent to the "{clientId}.#{numOpsGenerated}"': ->
    txn = new Txn '0', { targ: 'count', type: 'set', val: 0 }
    txn.id.should.equal "0.#{++_clientVer}"

  'should be able to instantiate an id without passing clientId, if clientId is in the prototype': ->
    Txn.prototype.clientId = '0'
    txn = new Txn { targ: 'count', type: 'set', val: 0 }
    txn.clientId.should.equal '0'
    delete Txn.prototype.clientId
    ++_clientVer

  'should not be able to instantiate an id without passing clientId, if clientId id not in the prototype': ->
    try {
      new Txn { targ: 'count', type: 'set', val: 0 }
    } catch (e) {
      e.should.be.an.instanceof(Error)
    }

  'vector clock should be a pair consisting of transaction id and recorded server version at the time of operation generation': ->
    txn = new Txn '0', { targ: 'count', type: 'set', val: 0 }
    txn.clock.should.eql ["0.#{++_clientVer}", 0]

  # Wire message protocol

  'it should be able to serialize to JSON': ->
    txn = new Txn('client0', { targ: 'count', type: 'set', val: 0 })
    txn.toJSON().should.eql {
      c: ["client0.#{++_clientVer}", 1] # Vector clock
      k: 'count'
      t: 'set'
      v: 0
    }

  'it should be able to de-serialize from JSON': ->
    txn = Txn.fromJSON {
      c: ['0.10', 2]
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

  'deserializing to create a transaction should not increment ver.client': ->
    txn = Txn.fromJSON {
      c: ['0.1', 2]
      k: 'count'
      t: 'set'
      v: 0
    }
    Txn.prototype.ver.client.should.equal _clientVer

  # Comparing transactions

  # Conflict detection
