expect = require 'expect.js'
should = require 'should'
{
  getLocks
  LOCK
  LOCK_TIMEOUT
  LOCK_TIMEOUT_MASK
  LOCKED_COMMIT
  UNLOCK
} = JournalRedisAdapter = require '../src/Journal/adapters/Redis'
transaction = require '../src/transaction.server'
redis = require 'redis'

describe 'JournalRedisAdapter', ->

  client = null

  beforeEach (done) ->
    client = redis.createClient()
    client.flushdb done

  afterEach (done) ->
    client.flushdb ->
      client.end()
      done()

  describe 'Lua locking', ->

    luaLock = (path, base, callback) ->
      locks = getLocks path
      client.eval LOCK, locks.length, locks..., base, (err, values) ->
        throw err if err
        lockVal = values[0]
        # The lower 32 bits of the lock value are a UNIX timestamp representing
        # when the transaction should timeout
        timeout = lockVal % LOCK_TIMEOUT_MASK
        # The upper 20 bits of the lock value are a counter incremented on each
        # lock request. This allows for one million unqiue transactions to be
        # addressed per second, which should be greater than Redis's capacity
        lockClock = Math.floor lockVal / LOCK_TIMEOUT_MASK
        callback err, values, timeout, lockClock

    luaUnlock = (path, lockVal, callback) ->
      locks = getLocks path
      client.eval UNLOCK, locks.length, locks..., lockVal, (err) ->
        callback err

    luaCommit = (path, lockVal, transaction, callback) ->
      locks = getLocks path
      client.eval LOCKED_COMMIT, locks.length, locks..., lockVal, JSON.stringify(transaction), (err, ver) ->
        callback err, ver

    it 'Lua lock script should return valid timeout and transaction count', (done) ->
      luaLock 'one', 0, (err, values, timeout, lockClock) ->
        should.equal null, err

        now = +Date.now() / 1000
        timeDiff = now + LOCK_TIMEOUT - timeout
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
      @timeout 5000
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
      setTimeout timeoutFn, (LOCK_TIMEOUT + 1) * 1000

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

  describe 'STM commit', ->

    lockQueue = null
    adapter = null
    subClient = redis.createClient()

    beforeEach ->
      lockQueue = {}
      adapter = new JournalRedisAdapter client, subClient

    afterEach ->
      subClient.quit()

    it 'different-client, different-path, simultaneous transaction should succeed', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create base: 0, id: '2.0', method: 'set', args: ['favorite-skittle', 'red']
      adapter._stmCommit lockQueue, txnOne, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        should.equal null, err
        done()

    it 'different-client, same-path, simultaneous transaction should fail', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create base: 0, id: '2.0', method: 'set', args: ['color', 'red']
      adapter._stmCommit lockQueue, txnOne, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        err.should.eql 'conflict'
        done()

    it 'different-client, same-path, sequential transaction should succeed', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create base: 1, id: '2.0', method: 'set', args: ['color', 'red']
      adapter._stmCommit lockQueue, txnOne, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        should.equal null, err
        done()

    it 'same-client, same-path transaction should succeed in order', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create base: 0, id: '1.1', method: 'set', args: ['color', 'red']
      adapter._stmCommit lockQueue, txnOne, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        should.equal null, err
        done()

    it 'same-client, same-path store transaction should fail in order', (done) ->
      txnOne = transaction.create base: 0, id: '#1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create base: 0, id: '#1.1', method: 'set', args: ['color', 'red']
      adapter._stmCommit lockQueue, txnOne, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        err.should.eql 'conflict'
        done()

    it 'same-client, same-path transaction should fail out of order', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create base: 0, id: '1.1', method: 'set', args: ['color', 'red']
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnOne, (err) ->
        err.should.eql 'conflict'
        done()

    it 'setting a child path should conflict', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['colors', ['green']]
      txnTwo = transaction.create base: 0, id: '2.0', method: 'set', args: ['colors.0', 'red']
      adapter._stmCommit lockQueue, txnOne, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        err.should.eql 'conflict'
        done()

    it 'setting a parent path should conflict', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['colors', ['green']]
      txnTwo = transaction.create base: 0, id: '2.0', method: 'set', args: ['colors.0', 'red']
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnOne, (err) ->
        err.should.eql 'conflict'
        done()

    it 'sending a duplicate transaction should be detected', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = txnOne.slice()
      adapter._stmCommit lockQueue, txnOne, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        err.should.eql 'duplicate'
        done()

    it 'a conflicting transaction with base of null or undefined should succeed', (done) ->
      txnOne = transaction.create base: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create base: null, id: '2.0', method: 'set', args: ['color', 'red']
      txnThree = transaction.create base: undefined, id: '3.0', method: 'set', args: ['color', 'blue']
      adapter._stmCommit lockQueue, txnOne, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnTwo, (err) ->
        should.equal null, err
      adapter._stmCommit lockQueue, txnThree, (err) ->
        should.equal null, err
        done()
