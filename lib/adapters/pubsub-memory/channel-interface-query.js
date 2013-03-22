var util = require('../../util')
  , transaction = require('../../transaction.server')

module.exports = createQueryInterface;

function createQueryInterface(pubSub, store) {
  return new QueryInterface(pubSub, store);
}

function QueryInterface(pubSub, store) {
  this.queryCoordinator = store._queryCoordinator;
}

QueryInterface.prototype.subscribe = function(subscriberId, pattern, ackCb) {
  return this.queryCoordinator.subscribe(subscriberId, pattern, ackCb);
};

QueryInterface.prototype.publish = function (msg, meta) {
  if (msg.type !== 'txn' || !meta) return;
  // TODO applyTxnToDoc only once, not once per channel type. Is it only done
  // here?
  var txn = msg.params.data
    , origDoc = meta.origDoc
    , newDoc = origDoc && util.deepCopy(origDoc)
  newDoc = transaction.applyTxnToDoc(txn, newDoc);
  this.queryCoordinator.publish(newDoc, origDoc, txn);
}

QueryInterface.prototype.unsubscribe = function(subscriberId, pattern, ackCb) {
  return this.queryCoordinator.unsubscribe(subscriberId, pattern, ackCb);
};

QueryInterface.prototype.hasSubscriptions = function(subscriberId) {
  return this.queryCoordinator.hasSubscriptions(subscriberId);
};

QueryInterface.prototype.subscribedTo = function(subscriberId, pattern) {
  return this.queryCoordinator.subscribedTo(subscriberId, pattern);
};
