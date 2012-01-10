module.exports =

  mergeAll: (to, froms...) ->
    for from in froms
      if from
        to[key] = value for key, value of from
    return to

  merge: (to, from) ->
    to[key] = value for key, value of from
    return to

  hasKeys: (obj, ignore) ->
    for key of obj
      continue if key is ignore
      return true
    return false
