MemorySync = require './MemorySync'

Memory = module.exports = ->
  @_data = {}
  @ver = 0
  return

Memory:: =
  flush: (callback) ->
    @_data = {}
    @ver = 0
    callback null
  
  _get: MemorySync::get
  get: (path, callback) ->
    value = @_get path
    callback null, value, @ver
  
  _set: MemorySync::set
  set: (path, value, ver, callback) ->
    try
      @_set path, value, ver
    catch err
      return callback err
    callback null, value
  
  _del: MemorySync::del
  del: (path, ver, callback) ->
    try
      @_del path, ver
    catch err
      return callback err
    callback null
  
  _lookup: MemorySync::_lookup
