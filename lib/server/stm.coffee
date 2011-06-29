redis = require 'redis'
txn = require './txn'

# abstract away logic for a redis lock strategy that uses WATCH/UNWATCH
lock = (client, path, callback, block, retries) ->
  retries ||= lock.maxRetries
  client.setnx path, +new Date, (err, didGetLock) ->
    throw callback err if err
    unless didGetLock
      # retry
      if --retries
        nextTry = () ->
          lock(client, path, callback, block, retries)
        return setTimeout nextTry, Math.pow(2, lock.maxRetries-retries+1) * 1000
      return callback new Error("Tried un-successfully to hold a lock #{lock.maxRetries} times")

    # releases the lock
    unlock = (callback) ->
      client.del path, (err) ->
        return callback err if err
        callback()

    # `exec` exposes a multi object for the callback to decorate.
    # After decoration, the lock is released, and the multi is exec'ed
    exec = (fn) ->
      multi = client.multi()
      fn(multi)
      multi.del path, (err) ->
        throw err if err
      multi.exec (err, replies) ->
        throw err if err
        callback null
    block unlock, exec

lock.maxRetries = 5

# stm singleton
stm = module.exports =
  connect: () ->
    @client = redis.createClient()

  version: (fn, refresh) ->
    if refresh or not @ver
      @redis.get 'version', (err, ver) ->
        return fn(err) if (err)
        @ver = ver
        fn(null, @ver)
    fn(@ver)

  attempt: (transaction, callback) ->
    lockpath = "lock.#{txn.path(transaction)}"
    lock @client, lockpath, callback, (unlock, exec) =>
      commit = =>
        # Commits our transaction
        exec (multi) =>
          multi.zadd 'changes', txn.base(transaction), JSON.stringify(transaction), (err) ->
            throw err if err
          multi.incr 'version', (err, nextVer) =>
            throw err if err
            @ver = nextVer

      # Check version
      return commit() if txn.base(transaction) == @ver

      # Fetch journal changes >= the transaction base
      @client.zrangebyscore 'changes', txn.base(transaction), '+inf', (err, changes) =>
        return callback err if err

        # Look for conflicts with the journal
        i = changes.length
        while i--
          if txn.isConflict transaction, JSON.parse(changes[i])
            return unlock (err) ->
              return callback err if err
              return callback(new Error("Conflict with journal"))

        # If we get this far, commit the transaction
        commit()
