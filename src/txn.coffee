# TODO Add set version of methods
module.exports =
  base: (tol) -> tol[0]
  id: (tol) -> tol[1]
  method: (tol) -> tol[2]
  path: (tol) -> tol[3]
  args: (tol) -> tol.slice 4
  
  conflict: (txnA, txnB) ->
    # txnA is a new transaction, and txnB is an already committed transaction
    
    # There is no conflict if the paths don't conflict
    return false if !@pathConflict(txnA[3], txnB[3])
    
    # There is no conflict if the transactions are from the same client
    # and the new transaction was from a later client version
    idA = txnA[1].split '.'
    idB = txnB[1].split '.'
    clientIdA = idA[0]
    clientIdB = idB[0]
    if clientIdA == clientIdB
      clientVerA = idA[1] - 0
      clientVerB = idB[1] - 0
      return false if clientVerA > clientVerB
    
    # There is no conflict if the new transaction has exactly the same method,
    # path, and arguments as the committed transaction
    lenA = txnA.length
    i = 2
    while i < lenA
      return true if txnA[i] != txnB[i]
      i++
    return true if lenA != txnB.length
    return false

  pathConflict: (pathA, pathB) ->
    # Paths conflict if either is a sub-path of the other
    return true if pathA == pathB
    pathALen = pathA.length
    pathBLen = pathB.length
    return false if pathALen == pathBLen
    if pathALen > pathBLen
      return pathA.charAt(pathBLen) == '.' && pathA.substring(0, pathBLen) == pathB
    return pathB.charAt(pathALen) == '.' && pathB.substring(0, pathALen) == pathA

  journalConflict: (transaction, ops) ->
    i = ops.length
    while i--
      return true if @conflict transaction, JSON.parse(ops[i])
    return false

