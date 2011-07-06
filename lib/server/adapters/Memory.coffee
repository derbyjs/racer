module.exports = Memory = () ->
  @_data = {}
  return

Memory:: =
  flush: (callback) ->
    @_data = {}
    callback null if callback
  set: (path, val, ver, callback) ->
    [base, relPath] = @extract path
    doc = @_data[base] || (@_data[base] = {})
    doc.ver = ver
    parts = relPath.split '.'
    parts.reduce( (toAssign, part, i) ->
      toAssign[part] = val if i == parts.length-1
      toAssign[part] ||= {}

    , doc)
    callback null if callback

  get: (path, callback) ->
    [base, relPath] = @extract path
    doc = @_data[base]
    parts = relPath.split '.'
    val = parts.reduce( (val, part) ->
      val[part]

    , doc)
    ver = doc.ver
    callback null, val, ver, doc if callback

  mget: (paths, callback) ->
    eachCb = (err, val, ver, doc) =>
      return if eachCb.didErr
      if (err)
        eachCb.didErr = true
        return callback err
      eachCb.vals.push val
      eachCb.vers.push ver
      return if --eachCb.remaining
      maxVer = eachCb.vers.reduce (max, ver) -> if max > ver then max else ver
      callback null, eachCb.vals, maxVer
      # err, data, maxVer
    eachCb.remaining = paths.length
    eachCb.vals = []
    eachCb.vers = []

    paths.forEach (path) =>
      @get path, eachCb

  extract: (path) ->
    parts = path.split '.'
    first = parts.slice(0,2).join('.')
    rest  = parts.slice(2).join('.')
    [first, rest]
