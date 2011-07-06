should = require 'should'
Stm = require 'server/Stm'
stm = new Stm()
mockSocketModel = require('../util/model').mockSocketModel

luaLock = (path, base, callback) ->
  locks = stm._getLocks path
  stm._client.eval Stm._LOCK, locks.length, locks..., base, (err, values) ->
    lockVal = values[0]
    # The lower 32 bits of the lock value are a UNIX timestamp representing
    # when the transaction should timeout
    timeout = lockVal % Stm._LOCK_TIMEOUT_MASK
    # The upper 20 bits of the lock value are a counter incremented on each
    # lock request. This allows for one million unqiue transactions to be
    # addressed per second, which should be greater than Redis's capacity
    lockClock = Math.floor lockVal / Stm._LOCK_TIMEOUT_MASK
    callback err, values, timeout, lockClock

luaUnlock = (path, lockVal, callback) ->
  locks = stm._getLocks path
  stm._client.eval Stm._UNLOCK, locks.length, locks..., lockVal, (err) ->
    callback err

luaCommit = (path, lockVal, transaction, callback) ->
  locks = stm._getLocks path
  stm._client.eval Stm._COMMIT, locks.length, locks..., lockVal, JSON.stringify(transaction), (err, ver) ->
    callback err, ver

module.exports =
  setup: (done) ->
    stm._client.flushdb (err) ->
      throw err if err
      done()
  teardown: (done) ->
    stm._client.flushdb (err) ->
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
  
  ### Test runs slowly, since it has to wait for a timeout
  
  'Lua lock script should replaced timed out locks': (done) ->
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      values[0].should.be.above 0
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      values.should.equal 0
    setTimeout ->
      luaLock 'color', 0, (err, values) ->
        should.equal null, err
        values[0].should.be.above 0
        done()
    , (Stm._LOCK_TIMEOUT + 1) * 1000
  ###
  
  'Lua unlock script should remove locking conflict': (done) ->
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      values[0].should.be.above 0
      
      luaUnlock 'color', values[0], (err) ->
        should.equal null, err
      luaLock 'color', 0, (err, values) ->
        should.equal null, err
        values[0].should.be.above 0
        done()
  
  # STM commit function tests:
  
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
