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

  _push: MemorySync::push
  push: (path, values..., ver, callback) ->
    try
      @_push arguments...
    catch err
      return callback err
    callback null, values...

  _pop: MemorySync::pop
  pop: (path, ver, callback) ->
    try
      @_pop arguments...
    catch err
      return callback err
    callback null

  _insertAfter: MemorySync::insertAfter
  insertAfter: (path, afterIndex, value, ver, callback) ->
    try
      @_insertAfter arguments...
    catch err
      return callback err
    callback null, afterIndex, value

  _insertBefore: MemorySync::insertBefore
  insertAfter: (path, beforeIndex, value, ver, callback) ->
    try
      @_insertBefore arguments...
    catch err
      return callback err
    callback null, beforeIndex, value

  _remove: MemorySync::remove
  remove: (path, startIndex, howMany, ver, callback) ->
    try
      @_remove arguments...
    catch err
      return callback err
    callback null, startIndex, howMany

  _splice: MemorySync::splice
  splice: (path, startIndex, removeCount, newMembers..., ver, callback) ->
    try
      @_splice arguments...
    catch err
      return callback err
    callback null, startIndex, removeCount, newMembers...
 
  _lookup: MemorySync::_lookup
