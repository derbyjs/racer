MemoryAdapter = require './adapters/Memory'
Stm = require './Stm'
transaction = require './transaction'

# Server vs Browser
# - Server should not keep track of local _data (only by proxy if using Store MemoryAdapter); Browser should
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
  @_adapter = adapter = new MemoryAdapter
  @_stm = new Stm

  pending = {}
  ver = 1
  maxVer = 0
  @_queue = (txn, ver) ->
    pending[ver] = txn
    maxVer = ver
  setInterval ->
    while ver <= maxVer
      break unless txn = pending[ver]
      method = transaction.method txn
      opArgs = transaction.opArgs txn
      opArgs.push ver, (err) ->
        # TODO: Better adapter error handling and potentially a second callback
        # to the caller of _commit when the adapter operation completes
        throw err if err
      adapter[method] opArgs...
      delete pending[ver]
      ver++
  , FLUSH_MS
  
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
  
  # Note that for now, store setters will only commit against base 0
  # TODO: Figure out how to better version store operations if they are to be
  # used for anything other than initialization code
  set: (path, value, callback) ->
    @_commit [0, '_.0', 'set', path, value], callback
  del: (path, callback) ->
    @_commit [0, '_.0', 'del', path], callback
    
  _commit: (txn, callback) ->
    queue = @_queue
    @_stm.commit txn, (err, ver) ->
      txn[0] = ver
      callback err, txn if callback
      return if err
      queue txn, ver
