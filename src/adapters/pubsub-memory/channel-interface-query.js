var util = require('../../util')
  , isServer = util.isServer
  , deepCopy = util.deepCopy
  , Memory = require('../../Memory')
  , transaction = require('../../transaction.server')
  , applyTxnToDoc = transaction.applyTxnToDoc;

console.assert(isServer);

module.exports = createQueryInterface;

function createQueryInterface (pubSub, store) {
  var queryCoordinator = store._queryCoordinator;

  // queryCoordinator defines subscribe, unsubscribe, hasSubscriptions, and subscribedTo
  return Object.create(queryCoordinator, {
    publish: { value:
      function (msg, meta) {
        var type = msg.type;
        if (type !== 'txn' || !meta) return;
        // TODO applyTxnToDoc only once, not once per channel type. Is it only done
        // here?
        var params = msg.params
          , txn = params.data
          , origDoc = meta.origDoc
          , newDoc;
        if (origDoc) newDoc = deepCopy(origDoc);
        newDoc = applyTxnToDoc(txn, newDoc);
        queryCoordinator.publish(newDoc, origDoc, txn);
      }
    }
  });
}
