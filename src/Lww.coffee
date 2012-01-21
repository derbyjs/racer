transaction = require './transaction.server'

Lww = module.exports = (@redisClient) ->
  return

Lww::commitFn = (store) ->
  redisClient = @redisClient
  return (txn, callback) ->
    # Increment version and store the transaction with a
    # score of the new version
    redisClient.eval COMMIT, 0, JSON.stringify(txn), (err, ver) ->
      throw err if err
      store._finishCommit txn, ver, callback

COMMIT = """
local ver = redis.call('incr', 'ver')
redis.call('zadd', 'txns', ver, ARGV[1])
return ver
"""
