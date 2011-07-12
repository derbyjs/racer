should = require 'should'
Stm = require 'Stm'
stm = new Stm()
mockSocketModel = require('./util/model').mockSocketModel
luaLock = require('./util/Stm').luaLock(stm)
luaUnlock = require('./util/Stm').luaUnlock(stm)
luaCommit = require('./util/Stm').luaCommit(stm)

module.exports =
  setup: (done) ->
    stm.flush (err) ->
      throw err if err
      done()
  teardown: (done) ->
    stm.flush (err) ->
      throw err if err
      done()
  
  # Redis Lua script tests:
  
  'Lua lock script should return valid timeout and transaction count': (done) ->
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
  
  'Lua lock script should truncate transaction count to 12 bits': (done) ->
    stm._client.set 'lockClock', 0xdffffe
    luaLock 'color', 0, (err, values, timeout, lockClock) ->
      should.equal null, err
      lockClock.should.be.equal 0xfffff
      done()
  
  'Lua lock script should detect conflicts properly': (done) ->
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
  'Lua unlock script should remove locking conflict': (done) ->
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
  
  'Lua commit script should add transaction to journal, increment version, and release locks': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      lockVal = values[0]
      lockVal.should.be.above 0
      
      luaCommit 'color', lockVal, txnOne, (err, ver) ->
        should.equal null, err
        ver.should.equal 1
        stm._client.zrange 'txns', 0, -1, (err, val) ->
          should.equal null, err
          val.should.eql [JSON.stringify txnOne]
        stm._client.get 'ver', (err, val) ->
          should.equal null, err
          val.should.eql 1
        luaLock 'color', 0, (err, values) ->
          should.equal null, err
          values[0].should.be.above 0
          done()
  
  'Lua commit script should abort if locks are no longer held': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      lockVal = values[0]
      lockVal.should.be.above 0
      
      luaUnlock 'color', lockVal, (err) ->
        should.equal null, err
      luaCommit 'color', lockVal, txnOne, (err, ver) ->
        should.equal null, err
        ver.should.equal 0
        stm._client.get 'txns', (err, val) ->
          should.equal null, err
          should.equal null, val
        stm._client.get 'ver', (err, val) ->
          should.equal null, err
          should.equal null, val
          done()
  
  'Lua commit should work with maximum sized transaction value': (done) ->
    stm._client.set 'lockClock', 0xffffe
    txnOne = [0, '1.0', 'set', 'color', 'green']
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
  
  'different-client, different-path, simultaneous transaction should succeed': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'favorite-skittle', 'red']
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, null, (err) ->
      should.equal null, err
      done()
  
  'different-client, same-path, simultaneous transaction should fail': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'red']
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, null, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'different-client, same-path, sequential transaction should succeed': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [1, '2.0', 'set', 'color', 'red']
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, null, (err) ->
      should.equal null, err
      done()
  
  'different-client, same-path, simultaneous, identical transaction should succeed': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'green']
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, null, (err) ->
      should.equal null, err
      done()
  
  'different-client, same-path, simultaneous, different method transaction should fail': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'del', 'color', 'green']
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, null, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'different-client, same-path, simultaneous, different args length transaction should fail': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'green', 0]
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, null, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'same-client, same-path transaction should succeed in order': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '1.1', 'set', 'color', 'red']
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, null, (err) ->
      should.equal null, err
      done()
  
  'same-client, same-path transaction should fail out of order': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '1.1', 'set', 'color', 'red']
    stm.commit txnTwo, null, (err) ->
      should.equal null, err
    stm.commit txnOne, null, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'setting a child path should conflict': (done) ->
    txnOne = [0, '1.0', 'set', 'colors', ['green']]
    txnTwo = [0, '2.0', 'set', 'colors.0', 'red']
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, null, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'setting a parent path should conflict': (done) ->
    txnOne = [0, '1.0', 'set', 'colors', ['green']]
    txnTwo = [0, '2.0', 'set', 'colors.0', 'red']
    stm.commit txnTwo, null, (err) ->
      should.equal null, err
    stm.commit txnOne, null, (err) ->
      err.code.should.eql 'STM_CONFLICT'
      done()
  
  'forcing a conflicting transaction should make it succeed': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'red']
    stm.commit txnOne, null, (err) ->
      should.equal null, err
    stm.commit txnTwo, force: true, (err) ->
      should.equal null, err
      done()
  
  'test client set roundtrip with STM': (done) ->
    [sockets, model] = mockSocketModel 'client0', (txn) ->
      stm.commit txn, null, (err, version) ->
        should.equal null, err
        version.should.equal 1
        txn[0] = version
        sockets.emit 'txn', txn
        model.get('color').should.eql 'green'
        done()
    model.set 'color', 'green'
  
  finishAll: (done) ->
    stm._client.end()
    done()

  ## !!!! PLACE ALL TESTS BEFORE finishAll
