transaction = require '../transaction.server'

exports = module.exports = (racer) ->
  racer.registerAdapter 'journal', 'Memory', JournalMemory

exports.useWith = server: true, browser: false

JournalMemory = ->
  @flush()
  return

JournalMemory::=
  flush: (callback) ->
    @_txns = []
    @_startId = (+new Date).toString 36
    callback?()

  startId: (callback) -> callback null, @_startId

  version: (callback) -> callback null, @_txns.length

  txnsSince: (ver, clientId, pubSub, callback) ->
    since = []
    return callback null, since unless pubSub.hasSubscriptions clientId

    txns = @_txns
    while txn = txns[ver++]
      if pubSub.subscribedTo clientId, transaction.getPath(txn)
        since.push txn
    callback null, since

  commitFn: (store, mode) -> commitFns[mode] this, store


commit = (txns, store, txn, callback) ->
  journalTxn = JSON.parse JSON.stringify txn
  ver = txns.push journalTxn
  transaction.setVer journalTxn, ver
  store._finishCommit txn, ver, callback

commitFns =
  lww: (self, store) -> (txn, callback) ->
    commit self._txns, store, txn, callback

  stm: (self, store) -> (txn, callback) ->
    ver = transaction.getVer txn
    txns = self._txns
    if ver?
      if typeof ver isnt 'number'
        # In case of something like store.set(path, value, callback)
        return callback? new Error 'Version must be null or a number'

      while item = txns[ver++]
        if err = transaction.conflict txn, item
          return callback? err

    commit txns, store, txn, callback
