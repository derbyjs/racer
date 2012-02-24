module.exports = Journal = (@_adapter) ->
  return

# TODO: Since transactions from different clients targeting the same path
# should be in conflict, then we should be able to abort a transaction just by
# knowing if the client associated with the same lock we want is not our client.
# This should result in an earlier response to the client than with the
# current approach

# TODO How can we improve this to work with multiple shards per transaction
#      which will eventually happen in the multi-path transaction scenario

Journal:: =
  flush: (callback) -> @_adapter.flush callback

  startId: (callback) -> @_adapter.startId callback

  getVer: (callback) -> @_adapter.getVer callback

  hasInvalidVer: (socket, ver, clientStartId) ->
    @_adapter.hasInvalidVer socket, ver, clientStartId

  unregisterClient: (clientId, callback) ->
    @_adapter.unregisterClient clientId, callback

  txnsSince: (ver, clientId, pubSub, callback) ->
    @_adapter.txnsSince ver, clientId, pubSub, callback

  nextTxnNum: (clientId, callback) -> @_adapter.nextTxnNum clientId, callback

  # TODO: Default mode should be 'ot'
  commitFn: (store, mode = 'lww') -> @_adapter.commitFn store, mode
