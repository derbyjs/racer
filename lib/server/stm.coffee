redis = require 'redis'
txn = require './txn'

utils =
  # abstract away logic for a redis lock strategy that uses WATCH/UNWATCH
  lock: (client, path, callback, block, retries) ->
    retries ||= @lock.maxRetries
    console.log "watching " + path
    client.watch path, (err, res) =>
      return callback err if err
      client.get path, (err, lock) =>
        return callback err if err
        if lock isnt null
          # retry
          client.unwatch path, (err, res) =>
            return callback err if err
            if retries--
              return this(client, path, callback, retries)
            return callback(new Error("Tried un-successfully to hold a lock #{@lock.maxRetries} times"))

        # releases the lock
        unlock = (callback) ->
          client.unwatch path, (err) ->
            throw err if err

        # `exec` sandwiches commandTriplets in-between the set/del commands that enable/disable the lock
        exec = (fn) ->
          console.log "executing multi for #{path}"
          multi = client.multi()
          multi.set path, true, (err) ->
            throw err if err
          fn(multi)
          console.log("!!! about to EXEC")
          multi.del path, callback
          multi.exec (err, replies) ->
            throw err if err
            console.log "DONE EXECing"
            callback null
        block unlock, exec, callback

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
    lockpath = "lock.#{txn.path(tol)}"
    utils.lock @client, lockpath, callback, (unlock, exec, callback) =>
      commit = () =>
        # Commits our transaction
        exec (multi) ->
          multi.zadd 'changes', txn.base(tol), tol, (err) ->
            throw err if err
          multi.incr 'version', (err, nextVer) =>
            throw err if err
            console.log "nextVer= #{nextVer}"
            @ver = nextVer

      # Check version
      return commit() if txn.base(tol) == @ver

      # Fetch journal changes >= the transaction base
      @client.zrangebyscore 'changes', txn.base(tol), '+inf', 'WITHSCORES', (err, changes) =>
        return callback err if err

        # Look for conflicts with the journal
        i = changes.length
        while i--
          if txn.isConflict tol, changes[i]
            unlock (err) ->
              return callback err if err
              return callback(new Error("Conflict with journal"))

        # If we get this far, commit the transaction
        console.log "committing #{tol}"
        commit()
