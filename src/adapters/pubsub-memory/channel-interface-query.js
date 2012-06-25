var util = require('../../util')
  , isServer = util.isServer
  , deepCopy = util.deepCopy
  , noop = util.noop
  , transaction = require('../../transaction')
  , Memory = require('../../Memory')
  , transaction = require('../../transaction.server');

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
        // TODO applyTxn only once, not once per channel type. Is it only done
        // here?
        var params = msg.params
          , txn = params.data
          , origDoc = meta.origDoc
          , newDoc;
        if (origDoc) {
          newDoc = deepCopy(origDoc);
        } else {
          // Otherwise this is a new doc
          var setVal = transaction.getArgs(txn)[1]
            , path = transaction.getPath(txn)
            , parts = path.split('.');
          if (parts.length === 2) {
            newDoc = setVal;
          } else {
            newDoc = { id: parts[1] };
            var curr = newDoc;
            for (var i = 2, l = parts.length; i < l - 1; i++) {
              var prop = parts[i];
              curr = curr[prop] = {};
            }
            curr[parts[l-1]] = setVal;
          }
        }
        newDoc = applyTxn(txn, newDoc);
        queryCoordinator.publish(newDoc, origDoc, txn);
      }
    }
  });
}

var memory = new Memory;
memory.setVersion = noop;
function applyTxn (txn, doc) {
  var path = transaction.getPath(txn)
    , parts = path.split('.')
    , ns = parts[0]
    , id = parts[1]

    , world = {}
    , data = { world: world };
  world[ns] = {};
  world[ns][id] = doc;

  transaction.applyTxn(txn, data, memory, -1);
  return memory.get(ns + '.' + id, data);
}
