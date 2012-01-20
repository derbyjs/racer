should = require 'should'
Stm = require '../src/Stm'
transaction = require '../src/transaction'
redis = require 'redis'
mockSocketModel = require('./util/model').mockSocketModel

describe 'Stm', ->

  client = null
  stm = null
  luaLock = null
  luaUnlock = null
  luaCommit = null

  beforeEach (done) ->
    client = redis.createClient()
    stm = new Stm client
    {luaLock, luaUnlock, luaCommit} = require('./util/Stm')(stm, client)
    client.flushdb done

  afterEach (done) ->
    client.flushdb ->
      client.end()
      done()
  
  # Redis Lua script tests:
  
  it 'Lua lock script should return valid timeout and transaction count', (done) ->
    luaLock 'one', 0, (err, values, timeout, lockClock) ->
      should.equal null, err
      
      now = +Date.now() / 1000
      timeDiff = now + Stm._LOCK_TIMEOUT - timeout
      timeDiff.should.be.within 0, 2

      lockClock.should.be.equal 1
    
    luaLock 'two', 0, (err, values, timeout, lockClock) ->
      should.equal null, err
      lockClock.should.be.equal 2
      done()
  
  it 'Lua lock script should truncate transaction count to 12 bits', (done) ->
    client.set 'lockClock', 0xdffffe
    luaLock 'color', 0, (err, values, timeout, lockClock) ->
      should.equal null, err
      lockClock.should.be.equal 0xfffff
      done()
  
  it 'Lua lock script should detect conflicts properly', (done) ->
    luaLock 'colors.0', 0, (err, values) ->
      should.equal null, err
      values[0].should.be.above 0
    luaLock 'colors.1', 0, (err, values) ->
      # Same parent but different leaf should not conflict
      should.equal null, err
      values[0].should.be.above 0
    luaLock 'colors.0', 0, (err, values) ->
      # Same path should conflict
      should.equal null, err
      values.should.equal 0
    luaLock 'colors', 0, (err, values) ->
      # Parent path should conflict
      should.equal null, err
      values.should.equal 0
    luaLock 'colors.0.name', 0, (err, values) ->
      # Child path should conflict
      should.equal null, err
      values.should.equal 0
      done()

  it 'Lua unlock script should remove locking conflict', (done) ->
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      lockVal = values[0]
      lockVal.should.be.above 0
      
      luaUnlock 'color', lockVal, (err) ->
        should.equal null, err
      luaLock 'color', 0, (err, values) ->
        should.equal null, err
        values[0].should.be.above 0
        done()
  
  it 'Lua commit script should add transaction to journal, increment version, and release locks', (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      lockVal = values[0]
      lockVal.should.be.above 0
      
      luaCommit 'color', lockVal, txnOne, (err, ver) ->
        should.equal null, err
        ver.should.equal 1
        client.zrange 'txns', 0, -1, (err, val) ->
          should.equal null, err
          val.should.eql [JSON.stringify txnOne]
        client.get 'ver', (err, val) ->
          should.equal null, err
          val.should.eql '1'
        luaLock 'color', 0, (err, values) ->
          should.equal null, err
          values[0].should.be.above 0
          done()
  
  it 'Lua commit script should abort if locks are no longer held', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      lockVal = values[0]
      lockVal.should.be.above 0
      
      luaUnlock 'color', lockVal, (err) ->
        should.equal null, err
      luaCommit 'color', lockVal, txnOne, (err, ver) ->
        should.equal null, err
        ver.should.equal 0
        client.get 'txns', (err, val) ->
          should.equal null, err
          should.equal null, val
        client.get 'ver', (err, val) ->
          should.equal null, err
          should.equal null, val
          done()

  it 'Lua lock script should replaced timed out locks @slow', (done) ->
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      values[0].should.be.above 0
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      values.should.equal 0
    timeoutFn = ->
      luaLock 'color', 0, (err, values) ->
        should.equal null, err
        values[0].should.be.above 0
        done()
    setTimeout timeoutFn, (Stm._LOCK_TIMEOUT + 1) * 1000

  it 'Lua commit should work with maximum sized transaction value', (done) ->
    client.set 'lockClock', 0xffffe
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    luaLock 'color', 0, (err, values, timeout, lockClock) ->
      should.equal null, err
      lockVal = values[0]
      lockVal.should.be.above 0
      lockClock.should.be.equal 0xfffff
      luaCommit 'color', lockVal, txnOne, (err, ver) ->
        should.equal null, err
        ver.should.equal 1
        done()

#  'a transaction should increase the version by 1': (done) ->
#    should.equal null, stm._ver
#    stm.commit [0, '1.0', 'set', 'color', 'green'], (err) ->
#      should.equal null, err
#      stm._ver.should.equal 1
#      done()
#
#  # compare clientIds = If same, then noconflict
#  # compare paths     = If different, then noconflict
#  # compare bases     = If same, then conflict
#  #                     If b1 > b2, and we are considering b1

  
  # STM commit function tests:
  
  it 'different-client, different-path, simultaneous transaction should succeed', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create base: 0, id: '2.0', method: 'set', args: ['favorite-skittle', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()
  
  it 'different-client, same-path, simultaneous transaction should fail', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create base: 0, id: '2.0', method: 'set', args: ['color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.should.eql 'conflict'
      done()
  
  it 'different-client, same-path, sequential transaction should succeed', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create base: 1, id: '2.0', method: 'set', args: ['color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()
  
  it 'same-client, same-path transaction should succeed in order', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create base: 0, id: '1.1', method: 'set', args: ['color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
      done()
  
  it 'same-client, same-path store transaction should fail in order', (done) ->
    txnOne = transaction.create base: 0, id: '#1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create base: 0, id: '#1.1', method: 'set', args: ['color', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.should.eql 'conflict'
      done()
  
  it 'same-client, same-path transaction should fail out of order', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create base: 0, id: '1.1', method: 'set', args: ['color', 'red']
    stm.commit txnTwo, (err) ->
      should.equal null, err
    stm.commit txnOne, (err) ->
      err.should.eql 'conflict'
      done()
  
  it 'setting a child path should conflict', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['colors', ['green']]
    txnTwo = transaction.create base: 0, id: '2.0', method: 'set', args: ['colors.0', 'red']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.should.eql 'conflict'
      done()
  
  it 'setting a parent path should conflict', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['colors', ['green']]
    txnTwo = transaction.create base: 0, id: '2.0', method: 'set', args: ['colors.0', 'red']
    stm.commit txnTwo, (err) ->
      should.equal null, err
    stm.commit txnOne, (err) ->
      err.should.eql 'conflict'
      done()
  
  it 'sending a duplicate transaction should be detected', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = txnOne.slice()
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      err.should.eql 'duplicate'
      done()
  
  it 'a conflicting transaction with base of null or undefined should succeed', (done) ->
    txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create base: null, id: '2.0', method: 'set', args: ['color', 'red']
    txnThree = transaction.create base: undefined, id: '3.0', method: 'set', args: ['color', 'blue']
    stm.commit txnOne, (err) ->
      should.equal null, err
    stm.commit txnTwo, (err) ->
      should.equal null, err
    stm.commit txnThree, (err) ->
      should.equal null, err
      done()
  
  it 'test client set roundtrip with STM', (done) ->
    [model, sockets] = mockSocketModel 'client0', 'txn', (txn) ->
      stm.commit txn, (err, version) ->
        should.equal null, err
        version.should.equal 1
        transaction.base txn, version
        sockets.emit 'txn', txn
        model.get('color').should.eql 'green'
        sockets._disconnect()
        done()
    model.set 'color', 'green'
