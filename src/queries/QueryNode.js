var MemoryQuery = require('./MemoryQuery')
  , QueryBuilder = require('./QueryBuilder')
  , transaction = require('../transaction')
  , DbMemory    = require('../adapters/db-memory').adapter
  , deepCopy = require('../util').deepCopy;

exports = module.exports = QueryNode;

// QueryNodes are located in a QueryHub where query pub sub and query fetches
// are routed.

function QueryNode (queryJson) {
  this.json = queryJson;
  this.hash = QueryBuilder.hash(queryJson);
  this.channel = '$q.' + this.hash;
  this.query = new MemoryQuery(queryJson);
  this.filter = this.query._filter;
}

QueryNode.prototype.results = function results (db, cb) {
  var dbQuery = new db.Query(this.json);
  return dbQuery.run(db, function (err, found) {
    if (db instanceof DbMemory) {
      if (err) return cb(err);
      return cb(null, deepCopy(found));
    }
    return cb(err, found);
  });
};

// TODO Where do we need to use cb?
QueryNode.prototype.maybePublish = function maybePublish (newDoc, oldDoc, txn, services, cb) {
  var pubSub = services.pubSub
    , filter = this.query._filter
    , path = transaction.getPath(txn)
    , ns = path.substring(0, path.indexOf('.'))
    , oldDocPasses = oldDoc && filter(oldDoc, ns)
    , newDocPasses = filter(newDoc, ns);

  // Handle all permutations of oldDocPasses x newDocPasses

  // The query didn't contain the doc pre- or post-mutation, so don't do
  // anything.
  if (!oldDocPasses && !newDocPasses) return;

  // The query contains the document pre- and post-mutation, so just publish
  // the mutation
  if (oldDocPasses && newDocPasses) {
    return publishFn(pubSub, 'txn', this.channel, txn);
  }

  var ver = transaction.getVer(txn)
    , path = transaction.getPath(txn)
    , ns = path.substring(0, path.indexOf('.'));

  // The query no longer contains the document, so tell any subscribed
  // clients to remove it.
  if (oldDocPasses && !newDocPasses) {
    return publishRmDoc(pubSub, this.channel, ns, oldDoc, ver);
  }

  // The query didn't contain the doc pre-mutation, but now it does contain
  // it, so tell the subscribed clients to add the doc.
  if (!oldDocPasses && newDocPasses)
    return publishAddDoc(pubSub, this.channel, ns, newDoc, ver, txn);
};

exports.publishFn     = publishFn;
exports.publishAddDoc = publishAddDoc;
exports.publishRmDoc  = publishRmDoc;

function publishFn (pubSub, type, channel, data) {
  pubSub.publish({type: type, params: { channel: channel, data: data }});
}

function publishAddDoc (pubSub, channel, ns, doc, ver, txn) {
  publishFn(pubSub, 'addDoc', channel, {ns: ns, doc: doc, ver: ver});
  publishFn(pubSub, 'txn', channel, txn);
}

function publishRmDoc (pubSub, channel, ns, doc, ver) {
  publishFn(pubSub, 'rmDoc', channel, {ns: ns, id: doc.id, ver: ver});
}

