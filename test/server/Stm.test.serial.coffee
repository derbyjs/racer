should = require 'should'
Stm = require 'server/Stm'
stm = new Stm()
mockSocketModel = require('../util/model').mockSocketModel

module.exports =
  setup: (done) ->
    stm._client.flushdb (err) ->
      throw err if err
      done()
  teardown: (done) ->
    stm._client.flushdb (err) ->
      throw err if err
      done()

  # compare clientIds = If same, then noconflict
  # compare paths     = If different, then noconflict
  # compare bases     = If same, then conflict
  #                     If b1 > b2, and we are considering b1

  '2 concurrent transactions from different clients and targeting the same path should callback for conflict resolution': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.should.be.an.instanceof Error
      done()

  '2 concurrent transactions from different clients and targeting different paths should be applied': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'favorite-skittle', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()

  '2 same-client transactions targetting the same path should be applied': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '1.1', 'set', 'color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()

  # TODO

  '2 out-of-order same-client transactions targetting the same path should be applied in the correct order': (done) ->
    done()

  'a transaction that was generated before the current base server version should callback for conflict resolution if it conflicts with a transaction in the journal that occurred at the same snapshot base version': (done) ->
    done()

  'a transaction that was generated before the current base server version should callback for conflict resolution if it conflicts with a transaction in the journal that occurred after its snapshot base version': (done) ->
    done()

  'a transaction that was generated before the current base server version should be applied if the only transactions in the journal it conflicts with are those that came before it': (done) ->
    done()

  'a transaction that was generated before the current base server version should be applied if the only transactions in the journal it conflicts with are those that came before it': (done) ->
    done()
  
  'test client set roundtrip with STM': (done) ->
    [serverSocket, model] = mockSocketModel 'client0', (message) ->
      [type, content, meta] = message
      type.should.eql 'txn'
      stm.commit content, (err) ->
        should.equal null, err
        serverSocket.broadcast message
        model.get('color').should.eql 'green'
        done()
    model.set 'color', 'green'
  
  finishAll: (done) ->
    stm._client.end()
    done()
