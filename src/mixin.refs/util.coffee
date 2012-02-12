module.exports =
  derefPath: (data, to) ->
    data.$deref?() || to

  lookupPath: (path, props, i) ->
    [path, props[i..]...].join '.'
