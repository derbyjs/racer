redis = require 'redis'
txn = require './txn'

MAX_RETRIES = 10

# TODO: Since transactions from different clients targeting the same path
# should be in conflict, then we should be able to abort a transaction just by
# knowing if the client associated with the same lock we want is not our client.
# This should result in an earlier response to the client than with the
# current approach

lock = (client, path, callback, block, retries = MAX_RETRIES) ->
  client.setnx path, +new Date, (err, gotLock) ->
    throw callback err if err
    unless gotLock
      # Retry
      if retries
        return setTimeout ->
          lock client, path, callback, block, --retries
        , (1 << (MAX_RETRIES - retries)) * 10
      return callback new Error "Tried un-successfully to hold a lock #{MAX_RETRIES} times"

    unlock = (callback) ->
      client.del path, (err) ->
        return callback err if err
        callback()

    # `exec` exposes a multi object for the callback to decorate.
    # After decoration, the lock is released, and the multi is exec'ed
    exec = (fn) ->
      multi = client.multi()
      fn multi
      multi.del path, (err) ->
        throw err if err
      multi.exec (err, replies) ->
        throw err if err
        callback null
    block unlock, exec

Stm = module.exports = ->
  @_client = redis.createClient()
  @_ver = null
  return
Stm:: =
  attempt: (transaction, callback) ->
    lockPath = 'lock.' + txn.path transaction
    base = txn.base transaction
    lock @_client, lockPath, callback, (unlock, exec) =>
      commit = ->
        # Commits our transaction
        exec (multi) ->
          multi.zadd 'changes', base, JSON.stringify(transaction), (err) ->
            throw err if err
          multi.incr 'version', (err, nextVer) ->
            throw err if err
            @_ver = nextVer

      # Check version
      return commit() if base == @_ver

      # Fetch journal changes >= the transaction base
      @_client.zrangebyscore 'changes', base, '+inf', (err, changes) ->
        return callback err if err

        # Look for conflicts with the journal
        i = changes.length
        while i--
          if txn.isConflict transaction, JSON.parse(changes[i])
            return unlock (err) ->
              return callback err if err
              return callback new Stm.ConflictError "Conflict with journal"

        # If we get this far, commit the transaction
        commit()

Stm.ConflictError = ->
  Error.apply this, arguments
  return
Stm.ConflictError::__proto__ = Error::
