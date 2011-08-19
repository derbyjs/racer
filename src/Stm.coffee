transaction = require './transaction.server'

MAX_RETRIES = 10
RETRY_DELAY = 5 # Initial delay in milliseconds. Exponentially increases

# TODO: Since transactions from different clients targeting the same path
# should be in conflict, then we should be able to abort a transaction just by
# knowing if the client associated with the same lock we want is not our client.
# This should result in an earlier response to the client than with the
# current approach

Stm = module.exports = (redisClient) ->

  lockQueue = {}
  
  # Callback has signature: fn(err, lockVal, txns)
  lock = (len, locks, txnsSince, path, retries, delay, callback) ->
    redisClient.eval LOCK, len, locks..., txnsSince, (err, values) ->
      return callback err if err
      if values[0]
        return callback null, values[0], values[1]
      if retries
        lockQueue[path] = queue = lockQueue[path] || []
        # Maintain a queue so that if this lock conflicts with another operation
        # on the same server and the same path, the lock can be retried immediately
        queue.push [len, locks, txnsSince, path, retries - 1, delay * 2, callback]
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
  
  @commit = (txn, callback) ->
    # If the base of a transaction is null or undefined, pass an empty string
    # for txnsSince, which indicates not to return a journal. Thus, no conflicts
    # will be found
    base = transaction.base txn
    txnsSince = if `base == null` then '' else base + 1
    path = transaction.path txn
    locks = getLocks path
    locksLen = locks.length
    lock locksLen, locks, txnsSince, path, MAX_RETRIES, RETRY_DELAY, (err, lockVal, txns) ->
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
  
  return

Stm._LOCK_TIMEOUT = LOCK_TIMEOUT = 3  # Lock timeout in seconds. Could be +/- one second
Stm._LOCK_TIMEOUT_MASK = LOCK_TIMEOUT_MASK = 0x100000000  # Use 32 bits for timeout
Stm._LOCK_CLOCK_MASK = LOCK_CLOCK_MASK = 0x100000  # Use 20 bits for lock clock

Stm._LOCK = LOCK = """
local now = os.time()
local path = KEYS[1]
for i, val in pairs(redis.call('smembers', path)) do
  if val % #{LOCK_TIMEOUT_MASK} < now then
    redis.call('srem', path, val)
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
local val = '0x' ..
  string.format('%x', redis.call('incr', 'lockClock') % #{LOCK_CLOCK_MASK}) ..
  string.format('%x', now + #{LOCK_TIMEOUT})
redis.call('set', 'l' .. path, val)
for i, path in pairs(KEYS) do
  redis.call('sadd', path, val)
end
local txns
if ARGV[1] ~= '' then txns = redis.call('zrangebyscore', 'txns', ARGV[1], '+inf') end
return {val, txns}
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
