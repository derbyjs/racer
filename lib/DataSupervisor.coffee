# Coordinates Stm and Store.
# Exposed to Model, which interacts with it via Model#_send

FLUSH_MS = 500

DataSupervisor = module.exports = (stm, store) ->
  @stm = stm
  @store = store

  @pendingStoreOps = pending = []
  flushOpsToStore = () ->
    store.exec op while op = pending.pop()
  setInterval flushOpsToStore, FLUSH_MS

DataSupervisor:: =
  tryTxn: (txn, callback) ->
    pendingStoreOps = @pendingStoreOps
    @stm.commit txn, (err, ver) ->
      return callback err if err
      if ver is not undefined
        txn[0] = ver
        pendingStoreOps.push txn
        return callback null, txn
      throw "Oops!"


  # Grabs data from Store
  # TODO Fetches any recent ops in the journal after the data value's base
  #   but which have not yet been applied to the store
  # TODO Apply the recent ops (if any) to the local in-memory version of the data
  #   from the store
  #
  # @param callback has signature fn(err, val, ver, doc)
  lookup: (path, callback) ->
    @store.get path, (err, val, ver, doc) ->
      throw err if err
      # TODO See above 2 TODOs
      callback err, val, ver, doc

  broadcast: ->
    # TODO
