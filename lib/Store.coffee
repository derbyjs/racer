_ = require './util'

if _.onServer
  Store = require './server/Store'
  MemoryAdapter = require './server/adapters/Memory'
  Stm = require './server/Stm'
  DataSupervisor = require './server/DataSupervisor'

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

store = module.exports =
  get: (path, callback) ->
    throw 'Unimplemented'
  set: (path, value, callback) ->
    throw 'Unimplemented'
  delete: (path, callback) ->
    throw 'Unimplemented'
  
  _send: -> false
  _setEndpoint: (service, config) ->
    if _.onServer
      @_setSocket service, config
    else
      @_setDataSupervisor service, config
  _setSocket: (socket, config) ->
    socket.connect()
    socket.on 'message', @_onMessage
    @_send = (txn) ->
      socket.send ['txn', txn]
      # TODO: Only return true if sent successfully
      return true
  _setDataSupervisor: (supervisor, config) ->
    @_send = (txn, callback) ->
      supervisor.tryTxn txn, callback
      return true



txn = require './txn'

# Stores interpret paths of the form: namespace + '.' + id + '.' + relPath

# store = new Store(MemoryAdapter, {...})
# store = new Store( new MemoryAdapter({...}) )
module.exports = Store = (adapter, config) ->
  @adapter = if 'function' == typeof adapter
               new adapter(config)
             else
               @adapter = adapter
  return

Store:: =
  flush: (callback) ->
    @adapter.flush callback
  set: (path, val, version, callback) ->
    if arguments.length == 3
      lastArgType = typeof arguments[2]
      throw new Error 'Missing version' if lastArgType == 'function'
    @adapter.set path, val, version, callback
  get: (path, callback) ->
    @adapter.get path, callback
  mget: (paths..., callback) ->
    @adapter.mget paths, callback
  
  exec: (op) ->
    ver = txn.base op
    method = txn.method op
    path = txn.path op
    args = txn.args op
    this[method](path, args...)
