module.exports = (racer) ->
  racer.adapters.journal.None = JournalNone

JournalNone = ->
  return

JournalNone::=
  flush: (callback) -> callback?()

  startId: (callback) -> callback null, null

  version: (callback) -> callback null, -1

  unregisterClient: (clientId, callback) -> callback?()

  # TODO: Perhaps there should be a way to refresh the entire model
  # state upon reconnection in this mode of operation
  txnsSince: (ver, clientId, pubSub, callback) -> callback null, []

  nextTxnNum: (clientId, callback) -> callback null, null

  commitFn: (store) -> (txn, callback) ->
    store._finishCommit txn, -1, callback
