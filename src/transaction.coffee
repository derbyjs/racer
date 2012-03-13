# Transactions are represented as an Array:
# [ base = version at the time of the transaction
# , transaction id
# , method
# , arguments]

module.exports =
  create: (obj) ->
    if obj.ops
      txn = [obj.base, obj.id, obj.ops]
    else
      txn = [obj.base, obj.id, obj.method, obj.args]
    return txn

  base: (txn, val) ->
    txn[0] = val if val isnt undefined
    return txn[0]

  getId: (txn) -> txn[1]
  setId: (txn, id) -> txn[1] = id

  clientIdAndVer: (txn) ->
    res = @getId(txn).split '.'
    res[1] = parseInt res[1], 10
    return res

  getMethod: (txn) -> txn[2]
  setMethod: (txn, name) -> txn[2] = name

  getArgs: (txn) -> txn[3]
  setArgs: (txn, vals) -> txn[3] = vals

  getPath: (txn) -> @getArgs(txn)[0]
  setPath: (txn, val) -> @getArgs(txn)[0] = val

  getMeta: (txn) -> txn[4]
  setMeta: (txn, vals) -> txn[4] = vals

  clientId: (txn, newClientId) ->
    [clientId, num] = @getId(txn).split '.'
    if newClientId isnt undefined
      @setId(txn, newClientId + '.' + num)
      return newClientId
    return clientId

  pathConflict: (pathA, pathB) ->
    # Paths conflict if equal or either is a sub-path of the other
    return 'equal' if pathA == pathB
    pathALen = pathA.length
    pathBLen = pathB.length
    return false if pathALen == pathBLen
    if pathALen > pathBLen
      return pathA.charAt(pathBLen) == '.' && pathA[0...pathBLen] == pathB && 'child'
    return pathB.charAt(pathALen) == '.' && pathB[0...pathALen] == pathA && 'parent'

  ops: (txn, ops) ->
    txn[2] = ops unless ops is undefined
    return txn[2]

  isCompound: (txn) ->
    return Array.isArray txn[2]

  op:
    create: (obj) ->
      op = [obj.method, obj.args]
      return op

    getMethod: (op) -> op[0]
    setMethod: (op, name) -> op[0] = name

    getArgs: (op) -> op[1]
    setArgs: (op, vals) -> op[1] = vals
