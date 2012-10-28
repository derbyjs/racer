var MemoryQuery = require('./MemoryQuery')
  , QueryBuilder = require('./QueryBuilder')
  , transaction = require('../../transaction')
  , DbMemory    = require('../../adapters/db-memory').adapter
  , deepCopy = require('../../util').deepCopy;

exports = module.exports = QueryNode;

/**
 * QueryNodes are located in a QueryHub where query pub sub and query fetches
 * are routed.
 */

function QueryNode (queryJson) {
  this.ns = queryJson.from;
  this.json = queryJson;
  this.hash = QueryBuilder.hash(queryJson);
  this.channel = '$q.' + this.hash;
  this.query = new MemoryQuery(queryJson);
  this.filter = this.query._filter;
}

QueryNode.prototype.result = function (db, cb) {
  var dbQuery = new db.Query(this.json);
  return dbQuery.run(db, function (err, result) {
    if (db instanceof DbMemory) {
      if (err) return cb(err);
      return cb(null, deepCopy(result));
    }
    return cb(err, result);
  });
};

QueryNode.prototype.shouldPublish = function (newDoc, oldDoc, txn, store, cb) {
  var filter = this.query._filter
    , path = transaction.getPath(txn)
    , ns = path.substring(0, path.indexOf('.'));

  if (ns !== this.ns) return false;
  var oldDocPasses = oldDoc && filter(oldDoc)
    , newDocPasses = newDoc && filter(newDoc);

  // Handle all permutations of oldDocPasses x newDocPasses

  // The query didn't contain the doc pre- or post-mutation, so don't do
  // anything.
  if (!oldDocPasses && !newDocPasses) return;

  // The query contains the document pre- and post-mutation, so just publish
  // the mutation
  if (oldDocPasses && newDocPasses) {
    return cb(null, [['txn']]);
  }

  var ver = transaction.getVer(txn)
    , path = transaction.getPath(txn);

  // The query no longer contains the document, so tell any subscribed
  // clients to remove it.
  if (oldDocPasses && !newDocPasses) {
    // Publish the newDoc, so we can see if the doc with the mutation still
    // satisfies some queries once received in the browser.
    return cb(null, [['rmDoc', ns, ver, newDoc, oldDoc.id]]);
  }

  // The query didn't contain the doc pre-mutation, but now it does contain
  // it, so tell the subscribed clients to add the doc.
  if (!oldDocPasses && newDocPasses)
    return cb(null, [['addDoc', ns, ver, newDoc]]);
};
