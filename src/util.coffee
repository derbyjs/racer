module.exports =

  merge: (a, b) ->
    a[k] = v for k, v of b
    return a

  hasKeys: (o) ->
    for k of o
      return true
    return false
