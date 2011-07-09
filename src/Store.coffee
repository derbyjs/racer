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
  @adapter = adapter = new MemoryAdapter
  @stm = new Stm

  @_pending = pending = {}
  setInterval ->
    lastWrittenVer = adapter._ver
    nextVerToWrite = ++lastWrittenVer
    while pending[nextVerToWrite]
      [method, args...] = pending[nextVerToWrite]
      adapter[method] args... # Implicitly increments adapter._ver
      delete pending[nextVerToWrite++]
  , FLUSH_MS
  return
  
Store:: =
  flush: (callback) ->
    done = false
    cb = (err) ->
      callback err, callback = null if callback && done || err
      done = true
    @adapter.flush cb
    @stm.flush cb
  
  get: (path, callback) ->
    @adapter.get path, callback
  
  # Note that for now, store setters will only commit against base 0
  # TODO: Figure out how to better version store operations if they are to be
  # used for anything other than initialization code
  set: (path, value, callback) ->
    @commit [0, '_.0', 'set', path, value], callback
  del: (path, callback) ->
    @commit [0, '_.0', 'del', path], callback
    
  commit: (txn, callback) ->
    pending = @_pending
    @stm.commit txn, (err, ver) ->
      # TODO: Callback after stm commit is successful instead of after
      # the adapter operation is complete
      if err then return callback && callback err
      pending[ver] = transaction.op(txn).concat(ver, callback)
