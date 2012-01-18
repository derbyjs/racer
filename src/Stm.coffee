transaction = require './transaction.server'
Serializer = require './Serializer'

MAX_RETRIES = 10
RETRY_DELAY = 5 # Initial delay in milliseconds. Exponentially increases

# TODO: Since transactions from different clients targeting the same path
# should be in conflict, then we should be able to abort a transaction just by
# knowing if the client associated with the same lock we want is not our client.
# This should result in an earlier response to the client than with the
# current approach

# TODO How can we improve this to work with multiple shards per transaction
#      which will eventually happen in the multi-path transaction scenario

Stm = module.exports = (redisClient, store) ->

  lockQueue = {}
  
  # Callback has signature: fn(err, lockVal, txns)
  lock = (numKeys, locks, sinceVer, path, retries, delay, callback) ->
    redisClient.eval LOCK, numKeys, locks..., sinceVer, (err, values) ->
      return callback err if err
      if values[0]
        return callback null, values[0], values[1]
      if retries
        queue = lockQueue[path] ||= []
        # Maintain a queue so that if this lock conflicts with another operation
        # on the same server and the same path, the lock can be retried immediately
        queue.push [numKeys, locks, sinceVer, path, retries - 1, delay * 2, callback]
        # Use an exponential timeout in case the conflict is because of a lock
        # on a child path or is coming from a different server
        return setTimeout ->
          lock args... if args = lockQueue[path].shift()
        , delay
      return callback 'lockMaxRetries'
  
  # Example output: getLocks("a.b.c") => [".a.b.c", ".a.b", ".a"]
  @_getLocks = getLocks = (path) ->
    lockPath = ''
    return (lockPath += '.' + segment for segment in path.split '.').reverse()
  
  @commit = commit = (txn, callback) ->
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
    locksLen = locks.length
    lock locksLen, locks, sinceVer, paths, MAX_RETRIES, RETRY_DELAY, (err, lockVal, txns) ->
      path = paths[0]
      return callback err if err
      
      # Check the new transaction against all transactions in the journal
      # since one after the transaction's base version
      if txns && conflict = transaction.journalConflict txn, txns
        return redisClient.eval UNLOCK, locksLen, locks..., lockVal, (err) ->
          return callback err if err
          callback conflict
      
      # Commit if there are no conflicts and the locks are still held
      redisClient.eval COMMIT, locksLen, locks..., lockVal, JSON.stringify(txn), (err, ver) ->
        return callback err if err
        return callback 'lockReleased' if ver is 0
        callback null, ver
        
        # If another transaction failed to lock because of this transaction,
        # shift it from the queue
        lock args... if (queue = lockQueue[path]) && args = queue.shift()


  if store

    store._commit = (txn, callback) ->
      ver = transaction.base txn
      if ver && typeof ver isnt 'number'
        # In case of something like @set(path, value, callback)
        throw new Error 'Version must be null or a number'
      commit txn, (err, ver) ->
        return callback && callback err, txn if err
        txnApplier.add txn, ver, callback

    ## Ensure Serialization of Transactions to the DB ##
    # TODO: This algorithm will need to change when we go multi-process,
    # because we can't count on the version to increase sequentially
    txnApplier = new Serializer
      withEach: (txn, ver, callback) ->
        store._finishCommit txn, ver, callback

  return


Stm._LOCK_TIMEOUT = LOCK_TIMEOUT = 3  # Lock timeout in seconds. Could be +/- one second
Stm._LOCK_TIMEOUT_MASK = LOCK_TIMEOUT_MASK = 0x100000000  # Use 32 bits for timeout
Stm._LOCK_CLOCK_MASK = LOCK_CLOCK_MASK = 0x100000  # Use 20 bits for lock clock

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
Stm._LOCK = LOCK = """
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

Stm._UNLOCK = UNLOCK = """
local val = ARGV[1]
local path = 'l' .. KEYS[1]
if redis.call('get', path) == val then redis.call('del', path) end
for i, path in pairs(KEYS) do
  redis.call('srem', path, val)
end
"""

Stm._COMMIT = COMMIT = """
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
