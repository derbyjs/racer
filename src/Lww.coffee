transaction = require './transaction.server'

Lww = module.exports = (redisClient, store) ->

  @commit = commit = (txn, callback) ->
    # Increment version and store the transaction with a
    # score of the new version
    redisClient.eval COMMIT, 0, JSON.stringify(txn), (err, ver) ->
      callback err, ver

  store._commit = (txn, callback) ->
    self = this
    commit txn, (err, ver) ->
      throw err if err
      self._finishCommit txn, ver, callback

  return

Lww._COMMIT = COMMIT = """
local ver = redis.call('incr', 'ver')
redis.call('zadd', 'txns', ver, ARGV[1])
return ver
"""
