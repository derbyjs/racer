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
