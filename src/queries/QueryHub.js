// A query hub manages some subset of the cloud's active queries, where
// "active" means that at least one client is subscribed to the query. A Store
// will interact with a QueryHub via a QueryCoordinator. The QueryCoordinator
// will route a query fetch, subscribe, and unsubscribe to the proper QueryHub
// (ideally doing so in a replicated and sharded env). A QueryHub is
// responsible for these incoming query-related responsibilities.
//
// TODO Outstanding Questions:
//
// Does it make more sense to route query fetches thru a Data Coordinator?
//
// Should we manipulate the query hub using mutator semantics?

var QueryBuilder = require('./QueryBuilder')
  , QueryNode = require('./QueryNode')
  , PaginatedQueryNode = require('./PaginatedQueryNode')
  , transaction = require('../transaction')
  ;

module.exports = QueryHub;

function QueryHub (store) {
  this._store = store;
  this._pubSub = store._pubSub;

  // TODO Re-eval need for reverseIndex -- not horizontally scalable
  // subscriberId -> (query hash -> true)
  this._reverseIndex = {};

  // ns -> query hash -> QueryNode
  this._queryNodes = {};
}

QueryHub.prototype._findOrCreateQNode = function _findOrCreateQNode (queryJson) {
  return lookupQNode(this, queryJson) || addQNode(this, queryJson);
};

// Registers the incoming query in the Hub
// @param {Object} query
function addQNode (hub, queryJson) {
  var hash = QueryBuilder.hash(queryJson)
    , reverseIndex = hub._reverseIndex
    , queryNodes = hub._queryNodes;
  var QNode = isPaginated(queryJson)
            ? PaginatedQueryNode
            : QueryNode;

  var ns = queryJson.from;
  queryNodes = queryNodes[ns] || (queryNodes[ns] = {});
  return queryNodes[hash] = new QNode(queryJson);
}

function isPaginated (queryJson) {
  return 'skip' in queryJson || 'limit' in queryJson;
}

// @param {Object} query json
// @returns {QueryNode}
function lookupQNode (hub, queryJson) {
  var ns = queryJson.from
    , nodes = hub._queryNodes[ns];
  return nodes && nodes[QueryBuilder.hash(queryJson)];
}

QueryHub.prototype.subscribe = function subscribe (subscriberId, queryJson, cb) {
  var reverseIndex = this._reverseIndex
    , hashes = reverseIndex[subscriberId] || (reverseIndex[subscriberId] = {})
    , hash = QueryBuilder.hash(queryJson);
  hashes[hash] = true;
  this._findOrCreateQNode(queryJson);
  this._pubSub.string.subscribe(subscriberId, ['$q.' + hash], cb);
};

// Possible function signatures are:
// unsubscribe(subscriberId, queryJson)
// unsubscribe(subscriberId, queryJson, cb)
// unsubscribe(subscriberId)
// unsubscribe(subscriberId, cb)
QueryHub.prototype.unsubscribe = function unsubscribe (subscriberId, queryJson, cb) {
  if (! queryJson || queryJson.constructor !== Object ) {
    var reverseIndex = this._reverseIndex
      , hashes = reverseIndex[subscriberId]
      , channels = [];
    delete reverseIndex[subscriberId];
    for (var hash in hashes) {
      channels.push('$q.' + hash);
    }
    if (cb = queryJson) {
      cb = finishAfter(channels.length, cb);
    }
  } else {
    channels.push('$q.' + QueryBuilder.hash(queryJson));
  }
  if (! channels.length) return cb && cb(null);
  this._pubSub.string.unsubscribe(subscriberId, channels, cb);
};

QueryHub.prototype.hasSubscriptions = function hasSubscriptions (subscriberId) {
  return subscriberId in this._reverseIndex;
};

QueryHub.prototype.subscribedTo = function subscribedTo (subscriberId, queryJson) {
  var hash = QueryBuilder.hash(queryJson);
  // TODO Probably a more efficient way to do this
  return this._pubSub.subscribedTo(subscriberId, '$q.' + hash);
};

// @param {Object} newDoc is the result of applying txn on oldDoc
// @param {Object} oldDoc is our document before applying txn
// @param {Array} txn is the transaction applied to oldDoc to get newDoc
QueryHub.prototype.publish = function publish (newDoc, oldDoc, txn) {
  var queryNodes = minSearchSpace(newDoc, oldDoc, txn, this._queryNodes);
  for (var hash in queryNodes) {
    var queryNode = queryNodes[hash];
    queryNode.maybePublish(newDoc, oldDoc, txn, {
        store: this._store
      , pubSub: this._pubSub
    });
  }
};

function minSearchSpace (newDoc, oldDoc, txn, queryNodes) {
  var path = transaction.getPath(txn)
    , ns = path.split('.')[0];

  return queryNodes[ns];
}

// TODO Return Promise for given fn signature
// TODO We don't need to create a query node for just fetching.
QueryHub.prototype.fetch = function fetch (queryJson, cb) {
  var queryNode = this._findOrCreateQNode(queryJson)
    , db = this._store._db;
  return queryNode.results(db, function (err, found) {
    // TODO Handle version consistency in face of concurrent writes during query
    return cb(err, found, db.version);
  });
};
