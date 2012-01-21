transaction = require './transaction'
pathParser = require './pathParser'

transaction.conflict = (txnA, txnB) ->
  # txnA is a new transaction, and txnB is an already committed transaction

  # There is no conflict if the paths don't conflict
  return false unless @pathConflict transaction.path(txnA), transaction.path(txnB)

  # There is no conflict if the transactions are from the same model client
  # and the new transaction was from a later client version.
  # However, this is not true for stores, whose IDs start with a '#'
  txnAId = transaction.id txnA
  if txnAId.charAt(0) != '#'
    [clientIdA, clientVerA] = transaction.clientIdAndVer txnA
    [clientIdB, clientVerB] = transaction.clientIdAndVer txnB
    if clientIdA == clientIdB
      return false if clientVerA > clientVerB

  # Ignore transactions with the same ID as an already committed transaction
  return 'duplicate' if txnAId == transaction.id txnB

  return 'conflict'

transaction.pathConflict = (pathA, pathB) ->
  # Paths conflict if either is a sub-path of the other
  return true if pathA == pathB
  pathALen = pathA.length
  pathBLen = pathB.length
  return false if pathALen == pathBLen
  if pathALen > pathBLen
    return pathA.charAt(pathBLen) == '.' && pathA.substring(0, pathBLen) == pathB
  return pathB.charAt(pathALen) == '.' && pathB.substring(0, pathALen) == pathA

transaction.journalConflict = (txn, txns) ->
  i = txns.length
  while i--
    return conflict if conflict = @conflict txn, JSON.parse(txns[i])
  return false

transaction.subscribed = (txn, subs) ->
  path = transaction.path txn
  return pathParser.matchesAnyPattern path, subs

module.exports = transaction
