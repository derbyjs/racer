##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

MemorySync = require './MemorySync'

Memory = module.exports = ->
  @_data = world: {}
  @_vers = ver: 0
  return

Memory:: =
  flush: (callback) ->
    @_data = world: {}
    @_vers = ver: 0
    callback null

  _prefillVersion: MemorySync::_prefillVersion
  _storeVer: MemorySync::_storeVer
  
  _get: MemorySync::getWithVersion
  get: (path, callback) ->
    try
      [val, ver] = @_get path
    catch err
      return callback err
    callback null, val, ver

['set', 'del', 'push', 'unshift', 'splice', 'pop', 'shift', 'insertAfter',
'insertBefore', 'remove', 'move'].forEach (method) ->
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

