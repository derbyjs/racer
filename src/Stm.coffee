transaction = require './transaction'
require './transaction.server'

MAX_RETRIES = 10  # Must be 30 or less given current delay algorithm
RETRY_DELAY = 10  # Delay in milliseconds. Exponentially increases on failure

# TODO: Since transactions from different clients targeting the same path
# should be in conflict, then we should be able to abort a transaction just by
# knowing if the client associated with the same lock we want is not our client.
# This should result in an earlier response to the client than with the
# current approach

Stm = module.exports = (redisClient) ->
  
  error = (code, message) ->
    err = new Error(message)
    err.code = code
    return err
  
  # Callback has signature: fn(err, lockVal, txns)
  lock = (len, locks, txnsSince, callback, retries = MAX_RETRIES) ->
    redisClient.eval LOCK, len, locks..., txnsSince, (err, values) ->
      throw err if err
      if values[0]
        return callback null, values[0], values[1]
      if retries
        return setTimeout ->
          lock len, locks, txnsSince, callback, --retries
        , (1 << (MAX_RETRIES - retries)) * RETRY_DELAY
      return callback error('STM_LOCK_MAX_RETRIES', 'Failed to aquire lock maximum times')
  
  # Example output: getLocks("a.b.c") => [".a.b.c", ".a.b", ".a"]
  @_getLocks = getLocks = (path) ->
    lockPath = ''
    return (lockPath += '.' + segment for segment in path.split '.').reverse()
  
  @commit = (txn, callback) ->
    # If the base of a transaction is null, pass an empty string for txnsSince,
    # which indicates not to return a journal, so no conflicts will be found
    base = transaction.base txn
    txnsSince = if base == null then '' else base + 1
    locks = getLocks transaction.path txn
    locksLen = locks.length
    lock locksLen, locks, txnsSince, (err, lockVal, txns) ->
      return callback err if err
      
      # Check the new transaction against all transactions in the journal
      # since one after the transaction's base version
      if txns && conflict = transaction.journalConflict txn, txns
        return redisClient.eval UNLOCK, locksLen, locks..., lockVal, (err) ->
          throw err if err
          if conflict is 'STM_DUPE'
            return callback error('STM_DUPE', 'Transaction already in journal')
          callback error('STM_CONFLICT', 'Conflict with journal')
      
      # Commit if there are no conflicts and the locks are still held
      redisClient.eval COMMIT, locksLen, locks..., lockVal, JSON.stringify(txn), (err, ver) ->
        throw err if err
        if ver is 0
          return callback error('STM_LOCK_RELEASED', 'Lock was released before commit')
        callback null, ver
  
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
