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
  
  _lookup: MemorySync::_lookup

for name in ['set', 'del']
  fn = MemorySync::[name]
  do (fn) ->
    Memory::[name] = (args..., callback) ->
      try
        out = fn.apply this, args
      catch err
        return callback err
      callback null, out