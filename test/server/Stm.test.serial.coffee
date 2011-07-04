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

  'different-client, different-path, simultaneous transaction should succeed': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'favorite-skittle', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()
  
  'different-client, same-path, simultaneous transaction should fail': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'different-client, same-path, sequential transaction should succeed': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [1, '2.0', 'set', 'color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()
  
  'different-client, same-path, simultaneous, identical transaction should succeed': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'green']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()
  
  'different-client, same-path, simultaneous, different method transaction should fail': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'del', 'color', 'green']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'different-client, same-path, simultaneous, different args length transaction should fail': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'green', 0]
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'same-client, same-path transaction should succeed in order': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '1.1', 'set', 'color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()
  
  'same-client, same-path transaction should fail out of order': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '1.1', 'set', 'color', 'red']
    stm.commit txnTwo, (err) ->
      should.equal null, err
    stm.commit txnOne, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'setting a child path should conflict': (done) ->
    txnOne = [0, '1.0', 'set', 'colors', ['green']]
    txnTwo = [0, '2.0', 'set', 'colors.0', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'setting a parent path should conflict': (done) ->
    txnOne = [0, '1.0', 'set', 'colors', ['green']]
    txnTwo = [0, '2.0', 'set', 'colors.0', 'red']
    stm.commit txnTwo, (err) ->
      should.equal null, err
    stm.commit txnOne, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'test client set roundtrip with STM': (done) ->
    [serverSocket, model] = mockSocketModel 'client0', (message) ->
      [type, content, meta] = message
      type.should.eql 'txn'
      stm.commit content, (err, version) ->
        should.equal null, err
        version.should.equal 1
        content[0] = version
        serverSocket.broadcast message
        model.get('color').should.eql 'green'
        done()
    model.set 'color', 'green'
  
  finishAll: (done) ->
    stm._client.end()
    done()
