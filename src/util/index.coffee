module.exports =

  merge: (a, b) ->
    a[k] = v for k, v of b
    return a

  hasKeys: (o, options = {}) ->
    ignore = options.ignore
    for k of o
      continue if ignore && -1 != ignore.indexOf k
      return true
    return false
