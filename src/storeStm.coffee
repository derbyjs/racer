Stm = require './Stm'
Serializer = require './Serializer'
transaction = require './transaction'

exports.init = (store, redisClient) ->

  stm = new Stm redisClient

  store._commit = (txn, callback) ->
    ver = transaction.base txn
    if ver && typeof ver isnt 'number'
      # In case of something like @set(path, value, callback)
      throw new Error 'Version must be null or a number'
    stm.commit txn, (err, ver) ->
      return callback && callback err, txn if err
      txnApplier.add txn, ver, callback

  ## Ensure Serialization of Transactions to the DB ##
  # TODO: This algorithm will need to change when we go multi-process,
  # because we can't count on the version to increase sequentially
  txnApplier = new Serializer
    withEach: (txn, ver, callback) ->
      store._finishCommit txn, ver, callback
