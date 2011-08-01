exports.merge = (a, b) ->
  a[k] = v for k, v of b
  return a

exports.anyKeys = (o) ->
  for k of o
    return true
  return false
