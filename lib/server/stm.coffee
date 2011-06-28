redis = require 'redis'

utils =
  # abstract away logic for a redis lock strategy that uses WATCH/UNWATCH
  lock: (client, path, callback, block, retries) ->
    retries ||= @lock.maxRetries
    client.watch path, (err, res) =>
      return callback err if err
      client.get path, (err, lock) =>
        return callback err if err
        if lock isnt null
          # retry
          client.unwatch (err, res) =>
            return callback err if err
            if retries--
              return this(client, path, callback, retries)
            return callback(new Error("Tried un-successfully to hold a lock #{@lock.maxRetries} times"))

        # releases the lock
        unlock = (callback) ->
          client.unwatch path, callback

        # `multi` sandwiches commandTriplets in-between the set/del commands that enable/disable the lock
        multi = (commandTriplets) ->
          commandTriplets.unshift ['set', ['path', true], callback]
          commandTriplets.push ['del', ['path'], callback]
          client.multi commandTriplets
        block unlock, multi, callback

utils.lock.maxRetries = 5

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

  # This ends up doing approximately
  #   path = 'lock.' + op[0]
  #   WATCH path
  #   lock = GET path
  #   if lock isnt null
  #     UNWATCH
  #     return if tries then commit(op, base, --tries) else 'error: max tries'
  #   changes = ZRANGEBYSCORE 'changes' base '+inf' WITHSCORES
  #   if conflicts op, changes
  #     UNWATCH
  #     return 'error: conflict'
  #   MULTI
  #   SET path true
  #   ZADD 'changes' base op
  #   INCR 'version'
  #   DEL path
  #   EXEC
  attempt: (tol, callback) ->
    lockpath = "lock.#{txn.id(tol)}"
    utils.lock @client, lockpath, callback, (unlock, multi, callback) =>
      commit = () ->
        # Commits our transaction
        multi(
          ['zadd', ['changes', txn.base(tol), tol], ->]
          ['incr', ['version'], ->]
        )

      # Check version
      return commit() if txn.base(tol) == @ver

      # Fetch journal changes >= the transaction base
      @client.zrangebyscore 'changes', txn.base(tol), '+inf', 'WITHSCORES', (err, changes) =>
        return callback err if err

        # Look for conflicts with the journal
        i = changes.length
        while i--
          if txn.hasConflicts tol, changes[i]
            unlock (err) ->
              return callback err if err
              return callback(new Error("Conflict with journal"))

        # If we get this far, commit the transaction
        commit()
