MemorySync = require './MemorySync'

Memory = module.exports = ->
  @_data = {}
  @_vers = ver: 0
  return

Memory:: =
  flush: (callback) ->
    @_data = {}
    @_vers = ver: 0
    callback null

  _prefillVersion: MemorySync::_prefillVersion
  _storeVer: MemorySync::_storeVer
  
  _get: MemorySync::get
  get: (path, callback) ->
    {val, ver} = @_get path
    callback null, val, ver
  
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
      @_push path, values..., ver
    catch err
      return callback err
    callback null, values...

  _pop: MemorySync::pop
  pop: (path, ver, callback) ->
    try
      @_pop path, ver
    catch err
      return callback err
    callback null

  _unshift: MemorySync::unshift
  unshift: (path, values..., ver, callback) ->
    try
      @_unshift path, values..., ver
    catch err
      return callback err
    callback null, values...

  _shift: MemorySync::shift
  shift: (path, ver, callback) ->
    try
      @_shift path, ver
    catch err
      return callback err
    callback null

  _insertAfter: MemorySync::insertAfter
  insertAfter: (path, afterIndex, value, ver, callback) ->
    try
      @_insertAfter path, afterIndex, value, ver
    catch err
      return callback err
    callback null, afterIndex, value

  _insertBefore: MemorySync::insertBefore
  insertBefore: (path, beforeIndex, value, ver, callback) ->
    try
      @_insertBefore path, beforeIndex, value, ver
    catch err
      return callback err
    callback null, beforeIndex, value

  _remove: MemorySync::remove
  remove: (path, startIndex, howMany, ver, callback) ->
    try
      @_remove path, startIndex, howMany, ver
    catch err
      return callback err
    callback null, startIndex, howMany

  _splice: MemorySync::splice
  splice: (path, startIndex, removeCount, newMembers..., ver, callback) ->
    try
      @_splice path, startIndex, removeCount, newMembers...
    catch err
      return callback err
    callback null, startIndex, removeCount, newMembers...
  
  _move: (path, from, to, ver, obj = @_data, options = {}) ->
    options.setVer = ver
    value = @lookup("#{path}.#{from}", obj, options).obj
    to += @lookup(path, obj, options).obj.length if to < 0
    if from > to
      @_insertBefore path, to, value, ver, obj, options
      from++
    else
      @_insertAfter path, to, value, ver, obj, options
    @_remove path, from, 1, ver, obj, options
  move: (path, from, to, ver, callback) ->
    try
      @_move path, from, to, ver
    catch err
      return callback err
    callback null, from, to
 
  lookup: MemorySync::lookup
