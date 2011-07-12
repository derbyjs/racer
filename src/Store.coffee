MemoryAdapter = require './adapters/Memory'
Stm = require './Stm'
transaction = require './transaction'

# Server vs Browser
# - Server should not keep track of local _data (only by proxy if using Store MemoryAdapter); Browser should (or should not and instead access it through a client-side MemoryAdapter; this would make for a more uniform abstraction)
# - Server should connect to DataSupervisor; Browser should connect to socket.io endpoint on server
# - Server should not deal with speculative models; Browser should
#   - Perhaps a special Store can control this?
# - Keeping track of transactions?
#
# Perhaps all server Store types have a Stm component. Then the
# abstraction is we just are interacting with some data store
# with STM capabilities

FLUSH_MS = 500

Store = module.exports = ->
  # TODO: Grab latest version from store and journal
  @_adapter = adapter = new MemoryAdapter
  @_stm = stm = new Stm
  sockets = null
  @_setSockets = (s) ->
    sockets = s

  # TODO: This algorithm will need to change when we go multi-process,
  # because we can't count on the version to increase sequentially
  pending = {}
  verToWrite = 1
  setInterval ->
    while txn = pending[verToWrite]
      args = transaction.args txn
      args.push verToWrite, (err) ->
        # TODO: Better adapter error handling and potentially a second callback
        # to the caller of _commit when the adapter operation completes
        throw err if err
      adapter[transaction.method txn] args...
      delete pending[verToWrite++]
  , FLUSH_MS
  
  @_commit = (txn, options, callback) ->
    stm.commit txn, options, (err, ver) ->
      txn[0] = ver
      callback err, txn if callback
      return if err
      sockets.emit 'txn', txn if sockets
      pending[ver] = txn
  
  return

Store:: =
  flush: (callback) ->
    done = false
    cb = (err) ->
      callback err, callback = null if callback && done || err
      done = true
    @_adapter.flush cb
    @_stm.flush cb
  
  get: (path, callback) ->
    @_adapter.get path, callback
  
  # Store operations are forced, which means that they will not be checked for
  # conflicts against already committed transactions
  set: (path, value, callback) ->
    @_commit [0, '_.0', 'set', path, value], force: true, callback
  del: (path, callback) ->
    @_commit [0, '_.0', 'del', path], force: true, callback
