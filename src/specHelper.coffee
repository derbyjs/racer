module.exports =
  isArray: (x) ->
    !!x && (Array.isArray(x) || typeof x is 'object' && Array.isArray(Object.getPrototypeOf x))

  create: (x) ->
    y = Object.create x
    y._proto = true
    if Array.isArray x
      y.toString = -> arr.slice().toString()
    return y

  reserved: ['_proto', 'toString']

  isSpeculative: (obj) -> '_proto' of obj
