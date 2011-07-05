redis = require 'redis'
txn = require './txn'

MAX_RETRIES = 10  # Must be 30 or less given current delay algorithm
RETRY_DELAY = 10  # Delay in milliseconds. Exponentially increases on failure

# Server and transaction ids are four base 36 characters
ID_CHARS = 4
ID_LEN = Math.pow(36, ID_CHARS)
TXN_ID_CHARS = ID_CHARS * 2
TXN_ID_LEN = Math.pow(36, TXN_ID_CHARS)

LOCK_TIMEOUT = 3  # Lock timeout in seconds. Could be +/- one second
LOCK = """
local now = os.time()
local path = KEYS[1]
for i, val in pairs(redis.call('smembers', path)) do
  if tonumber(val:sub(#{TXN_ID_CHARS + 1})) < now then
    redis.call('srem', path, val)
  else
    return 0
  end
end
for i, path in pairs(KEYS) do
  path = 'l' .. path
  local val = redis.call('get', path)
  if val then
    if tonumber(val:sub(#{TXN_ID_CHARS + 1})) < now then
      redis.call('del', path)
    else
      return 0
    end
  end
end
local val = ARGV[1] .. (now + #{LOCK_TIMEOUT})
redis.call('set', 'l' .. path, val)
for i, path in pairs(KEYS) do
  redis.call('sadd', path, val)
end
local ops = redis.call('zrangebyscore', 'ops', ARGV[2], '+inf')
return {val, ops}
"""
UNLOCK = """
local val = ARGV[1]
local path = 'l' .. KEYS[1]
if redis.call('get', path) == val then redis.call('del', path) end
for i, path in pairs(KEYS) do
  redis.call('srem', path, val)
end
"""
COMMIT = """
local val = ARGV[1]
local path = 'l' .. KEYS[1]
local fail = false
if redis.call('get', path) == val then redis.call('del', path) else fail = true end
for i, path in pairs(KEYS) do
  if redis.call('srem', path, val) == 0 then return 0 end
end
if fail then return 0 end
local ver = redis.call('incr', 'ver')
redis.call('zadd', 'ops', ver - 1, ARGV[2])
return ver
"""

# TODO: Since transactions from different clients targeting the same path
# should be in conflict, then we should be able to abort a transaction just by
# knowing if the client associated with the same lock we want is not our client.
# This should result in an earlier response to the client than with the
# current approach

Stm = module.exports = ->
  @_client = client = redis.createClient()
  
  txnNum = 0
  serverId = 0
  # The transaction counter is added to the server ID and then converted to a
  # base 36 string. The extra value used to make a fixed length string is then
  # removed with the substring method.
  nextTxnId = -> (serverId + (txnNum++ % ID_LEN)).toString(36).substr(1)
  client.incr 'serverId', (err, value) ->
    throw err if err
    # TODO: Simply limiting the server id's bits is likely to cause problems.
    # There shouldn't be more than 1.7 M servers simultaneously connected
    # to the same Redis instance, but it is likely that some will be much longer
    # running than others, so two serverIds could conflict, causing locks to
    # repeatedly fail. A better scheme for assigning unique server ids should
    # be implemented eventually.
    
    # Value is truncated to the maximum length then shifted to the upper bits.
    # One greater than the max transaction value is added so that the toString
    # function returns a fixed number of characters
    serverId = (value % ID_LEN) * ID_LEN + TXN_ID_LEN
  
  error = (code, message) ->
    err = new Error()
    err.code = code
    err.message = message
    return err
  
  lock = (len, locks, txnNum, base, callback, retries = MAX_RETRIES) ->
    client.eval LOCK, len, locks..., txnNum, base, (err, values) ->
      throw err if err
      unless values[0]
        # Retry
        if retries
          return setTimeout ->
            lock len, locks, txnNum, base, callback, --retries
          , (1 << (MAX_RETRIES - retries)) * RETRY_DELAY
        return callback error 'STM_LOCK_MAX_RETRIES', 'Failed to aquire lock maximum times'
      callback null, values[0], values[1]
  
  @commit = (transaction, callback) ->
    path = txn.path transaction
    base = txn.base transaction
    lockPath = ''
    locks = (lockPath += '.' + segment for segment in path.split '.').reverse()
    locksLen = locks.length
    lock locksLen, locks, nextTxnId(), base, (err, lockVal, ops) ->
      callback err if err
      
      # Check for conflicts with the journal
      i = ops.length
      while i--
        if txn.conflict transaction, JSON.parse(ops[i])
          return client.eval UNLOCK, locksLen, locks..., lockVal, (err) ->
            throw err if err
            callback error 'STM_CONFLICT', 'Conflict with journal'
      
      # Commit if there are no conflicts and the locks are still held
      client.eval COMMIT, locksLen, locks..., lockVal, JSON.stringify(transaction), (err, ver) ->
        throw err if err
        if ver is 0
          return callback error 'STM_LOCK_RELEASED', 'Lock was released before commit'
        callback null, ver
  
  return
