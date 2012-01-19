##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

MemorySync = require './MemorySync'
MUTATORS = ['set', 'del', 'push', 'unshift', 'insert', 'pop', 'shift', 'remove', 'move']

Memory = module.exports = ->
  @_data = world: {}
  @version = 0
  return

Memory:: =
  flush: (callback) ->
    @_data = world: {}
    @version = 0
    callback null

  setVersion: MemorySync::setVersion

  _get: MemorySync::get
  get: (path, callback) ->
    try
      val = @_get path
    catch err
      return callback err
    callback null, val, @version

  setupDefaultPersistenceRoutes: (store) ->
    adapter = @
    for method in MUTATORS
      store.defaultRoute method, '*', do (method) ->
        ->
          [pathPlusArgsPlusDone..., next] = arguments
          adapter[method] pathPlusArgsPlusDone...
    store.defaultRoute 'get', '*', (path, done, next) ->
      adapter.get path, done
    store.defaultRoute 'get', '', (path, done, next) ->
      adapter.get '', done
    return

MUTATORS.forEach (method) ->
  alias = '_' + method
  Memory::[alias] = fn = MemorySync::[method]
  Memory::[method] = switch fn.length
    when 3 then (path, ver, callback) ->
      try
        @[alias] path, ver, null
      catch err
        return callback err
      callback null
    when 4 then (path, arg0, ver, callback) ->
      try
        @[alias] path, arg0, ver, null
      catch err
        return callback err
      callback null, arg0
    when 5 then (path, arg0, arg1, ver, callback) ->
      try
        @[alias] path, arg0, arg1, ver, null
      catch err
        return callback err
      callback null, arg0, arg1
    else (path, args..., ver, callback) ->
      try
        @[alias] path, args..., ver, null
      catch err
        return callback err
      callback null, args...
