Model = require '../Model'

Memory = module.exports = ->
  @_data = {}
  @_ver = 0
  return

Memory:: =
  flush: (callback) ->
    @_data = {}
    @_ver = 0
    callback null if callback
  
  _set: Model::_set
  set: (path, value, ver, callback) ->
    @_set path, value
    @_ver = ver
    callback null if callback
  
  _del: Model::_del
  del: (path, ver, callback) ->
    @_del path
    @_ver = ver
    callback null if callback
  
  get: (path, callback) ->
    obj = @_data
    value = if path then @_lookup(path, obj: obj).obj else obj
    callback null, value, @_ver if callback

  # mget: (paths, callback) ->
  #   eachCb = (err, val, ver, doc) =>
  #     return if eachCb.didErr
  #     if (err)
  #       eachCb.didErr = true
  #       return callback err
  #     eachCb.vals.push val
  #     eachCb.vers.push ver
  #     return if --eachCb.remaining
  #     maxVer = eachCb.vers.reduce (max, ver) -> if max > ver then max else ver
  #     callback null, eachCb.vals, maxVer
  #     # err, data, maxVer
  #   eachCb.remaining = paths.length
  #   eachCb.vals = []
  #   eachCb.vers = []
  # 
  #   paths.forEach (path) =>
  #     @get path, eachCb
  
  _lookup: Model::_lookup
