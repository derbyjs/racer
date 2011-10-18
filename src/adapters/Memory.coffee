##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

MemorySync = require './MemorySync'
{all: mutators} = require '../mutators'

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

for method, {numArgs} of mutators
  do (method, numArgs) ->
    alias = '_' + method
    Memory::[alias] = MemorySync::[method]
    Memory::[method] = switch numArgs
      when 0 then (path, ver, callback) ->
        try
          @[alias] path, ver, null
        catch err
          return callback err
        callback null
      when 1 then (path, arg0, ver, callback) ->
        try
          @[alias] path, arg0, ver, null
        catch err
          return callback err
        callback null, arg0
      when 2 then (path, arg0, arg1, ver, callback) ->
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

