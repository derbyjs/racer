# TODO Add set version of methods
module.exports =
  create: (obj) ->
    txn = [obj.base, obj.id, obj.method, obj.args]
    txn.push obj.meta if obj.meta
    return txn

  base: (txn, val) ->
    txn[0] = val if val isnt undefined
    return txn[0]
  
  id: (txn, val) ->
    txn[1] = val if val isnt undefined
    return txn[1]
  
  clientIdAndVer: (txn) ->
    res = @id(txn).split '.'
    res[1] = parseInt res[1], 10
    return res

  method: (txn, name) ->
    txn[2] = name if name isnt undefined
    return txn[2]

  args: (txn, vals) ->
    if vals isnt undefined
      txn[3] = vals
#      txn.splice 3, txn.length-3, vals...
#      return vals
#    return txn.slice 3
    return txn[3]

  path: (txn, val) ->
    @args(txn)[0]
#    txn[3] = path if val isnt undefined
#    return txn[3]

  clientId: (txn, newClientId) ->
    [clientId, num] = @id(txn).split '.'
    if newClientId isnt undefined
      @id(txn, newClientId + '.' + num)
      return newClientId
    return clientId

  meta: (txn, obj) ->
    txn[4] = obj if obj isnt undefined
    return txn[4]
