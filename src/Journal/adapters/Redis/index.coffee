transaction = require '../../../transaction.server'
Serializer = require '../../../Serializer'
redisInfo = require './redisInfo'
Promise = require '../../../Promise'

exports = module.exports = JournalRedisAdapter = (@_redisClient, @_subClient) ->
  startIdPromise = @_startIdPromise = new Promise

  # TODO: Make sure there are no weird race conditions here, since we are
  # caching the value of starts and it could potentially be stale when a
  # transaction is received
  # TODO: Make sure this works when redis crashes and is restarted
  redisStarts = null
  ignoreSubscribe = false
  do subscribeToStarts = (db) ->
    return ignoreSubscribe = false if ignoreSubscribe

    # Calling select right away queues the command before any commands that
    # a client might add before connect happens. If select is not queued first,
    # the subsequent commands could happen on the wrong db
    if db isnt undefined
      return _redisClient.select db, (err) ->
        throw err if err
        subscribeToStarts()

    redisInfo.subscribeToStarts _subClient, _redisClient, (starts) ->
      redisStarts = starts
      startIdPromise.clearValue() if startIdPromise.value
      {0: firstStart} = starts
      [startId] = firstStart
      startIdPromise.fulfill startId

  # Ignore the first connect event
  ignoreSubscribe = true
  _redisClient.on 'connect', subscribeToStarts
  _redisClient.on 'end', ->
    redisStarts = null
    startIdPromise.clearValue()

  return

JournalRedisAdapter::=
  flush: (callback) ->
    self = this
    redisClient = self._redisClient
    # TODO Be more granular about this. Remove ind keys instead of flushdb
    redisClient.flushdb (err) ->
      return callback err if err
      redisInfo.onStart redisClient, (err) ->
        return callback err if err
        startIdPromise = self._startIdPromise
        startIdPromise.clearValue() if startIdPromise?.fulfilled
        callback null

  startId: (callback) -> @_startIdPromise.on callback

  getVer: (callback) -> @_redisClient.get 'ver', callback

  # TODO Combine ver and clientStartId into a vector clock
  hasInvalidVer: (socket, ver, clientStartId) ->
    startIdPromise = @_startIdPromise
    # Don't allow a client to connect unless there is a valid startId to
    # compare the model's against
    unless startIdPromise.value
      socket.disconnect()
      return true
    # TODO: Map the client's version number to the Stm's and update the client
    # with the new startId unless the client's version includes versions that
    # can't be mapped
    unless clientStartId && clientStartId == startIdPromise.value
      socket.emit 'fatalErr', "clientStartId != startId (#{clientStartId} != #{startIdPromise.value})"
      return true
    return false

  genClientId: (callback) ->
    @_redisClient.incr 'clientClock', (err, val) ->
      return callback err if err
      clientId = val.toString(36)
      callback null, clientId

  unregisterClient: (clientId, callback) ->
    @_redisClient.del 'txnClock.' + clientId, (err, val) ->
      callback err

  txnsSince: (ver, clientId, pubSub, callback) ->
    return callback [] unless pubSub.hasSubscriptions clientId

    # TODO Replace with a LUA script that does filtering?
    @_redisClient.zrangebyscore 'txns', ver, '+inf', 'withscores', (err, vals) ->
      throw err if err
      txn = null
      txns = []
      for val, i in vals
        if i % 2
          continue unless pubSub.subscribedToTxn clientId, txn
          transaction.base txn, +val
          txns.push txn
        else
          txn = JSON.parse val
      callback txns

  nextTxnNum: (clientId, callback) ->
    @_redisClient.incr 'txnClock.' + clientId, (err, value) ->
      return callback err if err
      callback null, value

  lwwCommitFn: (store) ->
    redisClient = @_redisClient

    return (txn, callback) ->
      # Increment version and store the transaction with a
      # score of the new version
      redisClient.eval LWW_COMMIT, 0, JSON.stringify(txn), (err, ver) ->
        return callback err if err
        store._finishCommit txn, ver, callback

  stmCommitFn: (store) ->
    ## Ensure Serialization of Transactions to the DB ##
    # TODO: This algorithm will need to change when we go multi-process,
    # because we can't count on the version to increase sequentially
    txnApplier = new Serializer
      withEach: (txn, ver, callback) ->
        store._finishCommit txn, ver, callback

    lockQueue = {}
    self = this
    return (txn, callback) ->
      ver = transaction.base txn
      if ver && typeof ver isnt 'number'
        # In case of something like @set(path, value, callback)
        return callback new Error 'Version must be null or a number'
      self._stmCommit lockQueue, txn, (err, ver) ->
        return callback && callback err, txn if err
        txnApplier.add txn, ver, callback

  _stmCommit: (lockQueue, txn, callback) ->
    self = this
    redisClient = self._redisClient
    # If the base of a transaction is null or undefined, pass an empty string
    # for sinceVer, which indicates not to return a journal. Thus, no conflicts
    # will be found
    base = transaction.base txn
    sinceVer = if `base == null` then '' else base + 1
    if transaction.isCompound txn
      paths = transaction.ops(txn).map (op) -> transaction.op.path op
    else
      paths = [transaction.path txn]
    locks = paths.reduce (locks, path) ->
      getLocks(path).forEach (lock) ->
        locks.push lock if -1 == locks.indexOf lock
      locks
    , []
    self._lock lockQueue, locks, sinceVer, paths, MAX_RETRIES, RETRY_DELAY, (err, numLocks, lockVal, txns) ->
      path = paths[0]
      return callback err if err

      # Check the new transaction against all transactions in the journal
      # since one after the transaction's base version
      if txns && conflict = transaction.journalConflict txn, txns
        return redisClient.eval UNLOCK, numLocks, locks..., lockVal, (err) ->
          return callback err if err
          callback conflict

      # Commit if there are no conflicts and the locks are still held
      redisClient.eval LOCKED_COMMIT, numLocks, locks..., lockVal, JSON.stringify(txn), (err, ver) ->
        return callback err if err
        return callback 'lockReleased' if ver is 0
        callback null, ver

        # If another transaction failed to lock because of this transaction,
        # shift it from the queue
        self._lock args... if (queue = lockQueue[path]) && args = queue.shift()

  _lock: (lockQueue, locks, sinceVer, path, retries, delay, callback) ->
    self = this
    redisClient = self._redisClient
    # Callback has signature: fn(err, lockVal, txns)
    numKeys = locks.length
    redisClient.eval LOCK, numKeys, locks..., sinceVer, (err, values) ->
      return callback err if err
      if values[0]
        return callback null, numKeys, values[0], values[1]
      if retries
        queue = lockQueue[path] ||= []
        # Maintain a queue so that if this lock conflicts with another operation
        # on the same server and the same path, the lock can be retried immediately
        queue.push [lockQueue, locks, sinceVer, path, retries - 1, delay * 2, callback]
        # Use an exponential timeout in case the conflict is because of a lock
        # on a child path or is coming from a different server
        return setTimeout ->
          self._lock args... if args = lockQueue[path].shift()
        , delay
      return callback 'lockMaxRetries', numLocks

# Example output:
# getLocks("a.b.c") => [".a.b.c", ".a.b", ".a"]
exports.getLocks = getLocks = (path) ->
  lockPath = ''
  return (lockPath += '.' + segment for segment in path.split '.').reverse()

exports.MAX_RETRIES = MAX_RETRIES = 10
# Initial delay in milliseconds. Exponentially increases
exports.RETRY_DELAY = RETRY_DELAY = 5

# Lock timeout in seconds. Could be +/- one second
exports.LOCK_TIMEOUT = LOCK_TIMEOUT = 3
# Use 32 bits for timeout
exports.LOCK_TIMEOUT_MASK = LOCK_TIMEOUT_MASK = 0x100000000
# Use 20 bits for lock clock
exports.LOCK_CLOCK_MASK = LOCK_CLOCK_MASK = 0x100000

# Each node/path has
# - A SET keyed by path containing a lock
# - A key named 'l' + path, that contains a lock
# - A lock encodes a global clock snapshot and an expiry
# Steps:
# 1. First, remove any expired locks contained by the SET of the most nested path. If there are any live locks in the SET, then abort.
# 2. For each path and subpath, remove any expired locks mapped to by a lock key 'l' + ... . If there are any live locks, then abort.
# 3. If we pass through step 1 and 2 without aborting, then create a single lock string that encodes (1) an incremented global lock clock and (2) an expiry
# 4. For each path and subpath, add this single lock string to the SETs associated with the paths and subpaths.
# 5. Fetch the transaction log since the incoming txn ver.
# 6. Return [lock string, truncated since transaction log]
exports.LOCK = LOCK = """
local now = os.time()
local path = KEYS[1]
for i, lock in pairs(redis.call('smembers', path)) do
  if lock % #{LOCK_TIMEOUT_MASK} < now then
    redis.call('srem', path, lock)
  else
    return 0
  end
end
for i, path in pairs(KEYS) do
  path = 'l' .. path
  local val = redis.call('get', path)
  if val then
    if val % #{LOCK_TIMEOUT_MASK} < now then
      redis.call('del', path)
    else
      return 0
    end
  end
end
local lock = '0x' ..
  string.format('%x', redis.call('incr', 'lockClock') % #{LOCK_CLOCK_MASK}) ..
  string.format('%x', now + #{LOCK_TIMEOUT})
redis.call('set', 'l' .. path, lock)
for i, path in pairs(KEYS) do
  redis.call('sadd', path, lock)
end
local txns
if ARGV[1] ~= '' then txns = redis.call('zrangebyscore', 'txns', ARGV[1], '+inf') end
return {lock, txns}
"""

exports.UNLOCK = UNLOCK = """
local val = ARGV[1]
local path = 'l' .. KEYS[1]
if redis.call('get', path) == val then redis.call('del', path) end
for i, path in pairs(KEYS) do
  redis.call('srem', path, val)
end
"""

exports.LOCKED_COMMIT = LOCKED_COMMIT = """
local val = ARGV[1]
local path = 'l' .. KEYS[1]
local fail = false
if redis.call('get', path) == val then redis.call('del', path) else fail = true end
for i, path in pairs(KEYS) do
  if redis.call('srem', path, val) == 0 then return 0 end
end
if fail then return 0 end
local ver = redis.call('incr', 'ver')
redis.call('zadd', 'txns', ver, ARGV[2])
return ver
"""

exports.LWW_COMMIT = LWW_COMMIT = """
local ver = redis.call('incr', 'ver')
redis.call('zadd', 'txns', ver, ARGV[1])
return ver
"""
