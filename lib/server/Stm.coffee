redis = require 'redis'
txn = require './txn'

MAX_RETRIES = 10
RETRY_DELAY = 10  # Delay in milliseconds. Exponentially increases on failure

LOCK_TIMEOUT = 3  # Lock timeout in seconds. Could be +/- one second
LOCK = """
local now = os.time()
local path = KEYS[1]
for i, val in pairs(redis.call('smembers', path)) do
  if (val % 0x100000000) < now then
    redis.call('srem', path, val)
  else
    return 0
  end
end
local val = ARGV[1] * 0x100000000 + now + #{LOCK_TIMEOUT}
for i, path in pairs(KEYS) do
  redis.call('sadd', path, val)
end
local ops = redis.call('zrangebyscore', 'ops', ARGV[2], '+inf')
return {val, ops}
"""
UNLOCK = """
local val = ARGV[1]
for i, path in pairs(KEYS) do
  redis.call('srem', path, val)
end
"""
COMMIT = """
local val = ARGV[1]
local fail = false
for i, path in pairs(KEYS) do
  if redis.call('srem', path, val) == 0 then fail = true end
end
if fail then return 0 end
local ver = redis.call('incr', 'ver')
redis.call('zadd', 'ops', ver, ARGV[2])
return ver
"""

# TODO: Since transactions from different clients targeting the same path
# should be in conflict, then we should be able to abort a transaction just by
# knowing if the client associated with the same lock we want is not our client.
# This should result in an earlier response to the client than with the
# current approach

lock = (client, len, locks, serverId, base, callback, retries = MAX_RETRIES) ->
  client.eval LOCK, len, locks..., serverId, base, (err, values) ->
    throw err if err
    unless values[0]
      # Retry
      if retries
        return setTimeout ->
          lock client, len, locks, serverId, base, callback, --retries
        , (1 << (MAX_RETRIES - retries)) * RETRY_DELAY
      return callback new Stm.LockMaxTries 'Failed to aquire lock maximum times'
    callback null, values[0], values[1]

Stm = module.exports = ->
  @_client = client = redis.createClient()
  serverId = 1
  
  @commit = (transaction, callback) ->
    path = txn.path transaction
    base = txn.base transaction
    lockPath = ''
    locks = (lockPath += '.' + segment for segment in path.split '.').reverse()
    locksLen = locks.length
    lock client, locksLen, locks, serverId, base, (err, lockVal, ops) ->
      callback err if err
      
      # Check for conflicts with the journal
      i = ops.length
      while i--
        if txn.conflict transaction, JSON.parse(ops[i])
          return client.eval UNLOCK, locksLen, locks, lockVal, (err) ->
            throw err if err
            callback new Stm.Conflict 'Conflict with journal'
      
      # Commit if there are no conflicts and the locks are still held
      client.eval COMMIT, locksLen, locks, lockVal, JSON.stringify(transaction), (err, ver) ->
        throw err if err
        if ver is 0
          return callback new Stm.LockTimeout 'Lock timed out before commit'
        callback null, ver
  
  return

makeError = (type) ->
  Stm[type] = ->
    Error.apply this, arguments
    return
  Stm[type]::__proto__ = Error::

makeError type for type in ['Conflict', 'LockMaxTries', 'LockTimeout']
