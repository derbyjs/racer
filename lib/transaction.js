module.exports = {
  base: function(txn) {
    return txn[0];
  },
  id: function(txn) {
    return txn[1];
  },
  op: function(txn) {
    return txn.slice(2);
  },
  method: function(txn) {
    return txn[2];
  },
  opArgs: function(txn) {
    return txn.slice(3);
  },
  path: function(txn) {
    return txn[3];
  },
  args: function(txn) {
    return txn.slice(4);
  },
  publicPath: function(name) {
    return !/(^_)|(\._)/.test(name);
  },
  conflict: function(txnA, txnB) {
    var clientIdA, clientIdB, clientVerA, clientVerB, i, idA, idB, lenA;
    if (!this.pathConflict(txnA[3], txnB[3])) {
      return false;
    }
    idA = txnA[1].split('.');
    idB = txnB[1].split('.');
    clientIdA = idA[0];
    clientIdB = idB[0];
    if (clientIdA === clientIdB) {
      clientVerA = idA[1] - 0;
      clientVerB = idB[1] - 0;
      if (clientVerA > clientVerB) {
        return false;
      }
    }
    lenA = txnA.length;
    i = 2;
    while (i < lenA) {
      if (txnA[i] !== txnB[i]) {
        return true;
      }
      i++;
    }
    if (lenA !== txnB.length) {
      return true;
    }
    return false;
  },
  pathConflict: function(pathA, pathB) {
    var pathALen, pathBLen;
    if (pathA === pathB) {
      return true;
    }
    pathALen = pathA.length;
    pathBLen = pathB.length;
    if (pathALen === pathBLen) {
      return false;
    }
    if (pathALen > pathBLen) {
      return pathA.charAt(pathBLen) === '.' && pathA.substring(0, pathBLen) === pathB;
    }
    return pathB.charAt(pathALen) === '.' && pathB.substring(0, pathALen) === pathA;
  },
  journalConflict: function(txn, ops) {
    var i;
    i = ops.length;
    while (i--) {
      if (this.conflict(txn, JSON.parse(ops[i]))) {
        return true;
      }
    }
    return false;
  }
};