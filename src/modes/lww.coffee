# TODO Add in redis adapter for version clock
transaction = require '../transaction.server'

module.exports = ({store}) ->
  new Lww store

Lww = (store) ->
  @_store = store
  @_nextVer = 1
  return

Lww::commit = (txn, cb) ->
  ver = @_nextVer++
  transaction.setVer txn, ver
  @_store._finishCommit txn, ver, cb

Lww::flush = (cb) -> cb null

Lww::version = (cb) ->
  cb(null, @_nextVer - 1)

Lww::snapshotSince = ({ver, clientId, subs}, cb) ->
  @_store.fetch clientId, subs, (err, data) ->
    return cb err if err
    cb null, {data}
