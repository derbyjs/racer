Stm = require 'server/Stm'

exports.luaLock = (stm) ->
  (path, base, callback) ->
    locks = stm._getLocks path
    stm._client.eval Stm._LOCK, locks.length, locks..., base, (err, values) ->
      throw err if err
      lockVal = values[0]
      # The lower 32 bits of the lock value are a UNIX timestamp representing
      # when the transaction should timeout
      timeout = lockVal % Stm._LOCK_TIMEOUT_MASK
      # The upper 20 bits of the lock value are a counter incremented on each
      # lock request. This allows for one million unqiue transactions to be
      # addressed per second, which should be greater than Redis's capacity
      lockClock = Math.floor lockVal / Stm._LOCK_TIMEOUT_MASK
      callback err, values, timeout, lockClock

exports.luaUnlock = (stm) ->
  (path, lockVal, callback) ->
    locks = stm._getLocks path
    stm._client.eval Stm._UNLOCK, locks.length, locks..., lockVal, (err) ->
      callback err

exports.luaCommit = (stm) ->
  (path, lockVal, transaction, callback) ->
    locks = stm._getLocks path
    stm._client.eval Stm._COMMIT, locks.length, locks..., lockVal, JSON.stringify(transaction), (err, ver) ->
      callback err, ver

