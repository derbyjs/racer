module.exports = (racer) ->
  racer.adapters.journal.None = JournalNone

JournalNone = ->
  return

JournalNone::=
  flush: (callback) -> callback?()

  startId: (callback) -> callback null

  version: (callback) -> callback null

  unregisterClient: (clientId, callback) -> callback?()

  # TODO: Perhaps there should be a way to refresh the entire model
  # state upon reconnection in this mode of operation
  txnsSince: (ver, clientId, pubSub, callback) -> callback null, []

  # TODO: Models should apply `null` numbered txns directly instead
  # of going through the txnApplier.
  nextTxnNum: (clientId, callback) -> callback null, null

  commitFn: (store) -> (txn, callback) ->
    store._finishCommit txn, null, callback
