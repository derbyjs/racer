transaction = require '../transaction.server'

exports = module.exports = (racer) ->
  racer.registerAdapter 'journal', 'Memory', JournalMemory

exports.useWith = server: true, browser: false
exports.decorate = 'racer'

JournalMemory = ->
  @flush()
  return

JournalMemory::=
  flush: (cb) ->
    @_txns = []
    @_startId = (+new Date).toString 36
    cb?()

  startId: (cb) -> cb null, @_startId

  version: (cb) -> cb null, @_txns.length

  add: (txn, opts, cb) ->
    @_txns.push txn
    @version cb

  # TODO Make consistent with txnsSince?
  eachTxnSince: (ver, {each, done}) ->
    txns = @_txns
    if ver is null
      return done()

    next = (err) ->
      if err
        return done err
      if txn = txns[ver++]
        return each null, txn, next
      return done null
    return next()

  txnsSince: (ver, clientId, pubSub, cb) ->
    since = []
    return cb null, since unless pubSub.hasSubscriptions clientId

    txns = @_txns
    while txn = txns[ver++]
      if pubSub.subscribedTo clientId, transaction.getPath(txn)
        since.push txn
    cb null, since
