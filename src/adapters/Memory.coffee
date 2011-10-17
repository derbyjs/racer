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
  _getWithVersion: MemorySync::getWithVersion
  get: (path, callback) ->
    try
      [val, ver] = @_getWithVersion path
    catch err
      return callback err
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
      @_push path, values..., ver, null
    catch err
      return callback err
    callback null, values...

  _pop: MemorySync::pop
  pop: (path, ver, callback) ->
    try
      @_pop path, ver, null
    catch err
      return callback err
    callback null

  _unshift: MemorySync::unshift
  unshift: (path, values..., ver, callback) ->
    try
      @_unshift path, values..., ver, null
    catch err
      return callback err
    callback null, values...

  _shift: MemorySync::shift
  shift: (path, ver, callback) ->
    try
      @_shift path, ver, null
    catch err
      return callback err
    callback null

  _insertAfter: MemorySync::insertAfter
  insertAfter: (path, afterIndex, value, ver, callback) ->
    try
      @_insertAfter path, afterIndex, value, ver, null
    catch err
      return callback err
    callback null, afterIndex, value

  _insertBefore: MemorySync::insertBefore
  insertBefore: (path, beforeIndex, value, ver, callback) ->
    try
      @_insertBefore path, beforeIndex, value, ver, null
    catch err
      return callback err
    callback null, beforeIndex, value

  _remove: MemorySync::remove
  remove: (path, startIndex, howMany, ver, callback) ->
    try
      @_remove path, startIndex, howMany, ver, null
    catch err
      return callback err
    callback null, startIndex, howMany

  _splice: MemorySync::splice
  splice: (path, args..., ver, callback) ->
    try
      @_splice path, args..., ver, null
    catch err
      return callback err
    callback null, args...
  
  _move: (path, from, to, ver, data) ->
    data ||= @_data
    vers = @_vers
    value = @_get "#{path}.#{from}", data
    to += @_get(path, data).length if to < 0
    if from > to
      @_insertBefore path, to, value, ver, data
      from++
    else
      @_insertAfter path, to, value, ver, data
    @_remove path, from, 1, ver, data
  move: (path, from, to, ver, callback) ->
    try
      @_move path, from, to, ver, null
    catch err
      return callback err
    callback null, from, to

