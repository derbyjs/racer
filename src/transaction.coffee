# Transactions are represented as an Array:
# [ ver = version at the time of the transaction
# , transaction id
# , method
# , arguments]

module.exports =
  create: (obj) ->
    if obj.ops
      txn = [obj.ver, obj.id, obj.ops]
    else
      txn = [obj.ver, obj.id, obj.method, obj.args]
    return txn

  getVer: (txn) -> txn[0]
  setVer: (txn, val) -> txn[0] = val

  getId: (txn) -> txn[1]
  setId: (txn, id) -> txn[1] = id

  clientIdAndVer: (txn) ->
    res = @getId(txn).split '.'
    res[1] = parseInt res[1], 10
    return res

  getMethod: (txn) -> txn[2]
  setMethod: (txn, name) -> txn[2] = name

  getArgs: (txn) -> txn[3]
  copyArgs: (txn) -> @getArgs(txn).slice()
  setArgs: (txn, vals) -> txn[3] = vals

  getPath: (txn) -> @getArgs(txn)[0]
  setPath: (txn, val) -> @getArgs(txn)[0] = val

  getMeta: (txn) -> txn[4]
  setMeta: (txn, vals) -> txn[4] = vals

  getClientId: (txn) -> @getId(txn).split('.')[0]
  setClientId: (txn, newClientId) ->
    [clientId, num] = @getId(txn).split '.'
    @setId(txn, newClientId + '.' + num)
    return newClientId

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
