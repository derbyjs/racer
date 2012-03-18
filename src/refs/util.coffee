module.exports =
  derefPath: (data, to) ->
    data.$deref?() || to

  lookupPath: (path, props, i) ->
    [path].concat(props[i..]).join '.'
