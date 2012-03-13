transaction = module.exports = require './transaction'

transaction.conflict = (txnA, txnB) ->
  # txnA is a new transaction, and txnB is an already committed transaction

  # There is no conflict if the paths don't conflict
  return false unless transaction.pathConflict transaction.getPath(txnA), transaction.getPath(txnB)

  # There is no conflict if the transactions are from the same model client
  # and the new transaction was from a later client version.
  # However, this is not true for stores, whose IDs start with a '#'
  txnAId = transaction.getId txnA
  if txnAId.charAt(0) != '#'
    [clientIdA, clientVerA] = transaction.clientIdAndVer txnA
    [clientIdB, clientVerB] = transaction.clientIdAndVer txnB
    if clientIdA == clientIdB
      return false if clientVerA > clientVerB

  # Ignore transactions with the same ID as an already committed transaction
  return 'duplicate' if txnAId == transaction.getId txnB

  return 'conflict'
