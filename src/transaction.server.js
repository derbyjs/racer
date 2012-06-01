var transaction = module.exports = require('./transaction');

/**
 * @param {Array} txnA is a new transaction
 * @param {Array} txnB is an already committed transaction
 */
transaction.conflict = function (txnA, txnB) {
  // There is no conflict if the paths do not conflict
  var pathA = transaction.getPath(txnA)
    , pathB = transaction.getPath(txnB);
  if (! transaction.pathConflict(pathA, pathB)) return false;

  // There is no conflict if the transactions are from the same model client
  // and the new transaction was from a later client version. However, this is
  // not true for stores, whose IDs start with a '#'
  var idA = transaction.getId(txnA)
    , pair, clientIdA, clientVerA, clientIdB, clientVerB;
  if (idA.charAt(0) !== '#') {
    pair = transaction.clientIdAndVer(txnA);
    clientIdA = pair[0];
    clientVerA = pair[1];

    pair = transaction.clientIdAndVer(txnB);
    clientIdB = pair[0];
    clientVerB = pair[1];

    if ((clientIdA === clientIdB) && (clientVerA > clientVerB)) {
      return false;
    }
  }

  if (idA === transaction.getId(txnB)) return 'duplicate';
  return 'conflict';
};
