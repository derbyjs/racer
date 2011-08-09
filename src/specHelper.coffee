module.exports =
  isArray: (x) ->
    Array.isArray(x) || typeof x == 'object' && Array.isArray(Object.getPrototypeOf x)

  create: (x) ->
    y = Object.create x
    y._proto = true
    if Array.isArray x
      y.toString = ->
        arr = []
        `for (var i = 0, l = arr.length; i < l; i++) arr.push[i];`
        arr.toString()
    return y

  reserved: ['_proto', 'toString']
