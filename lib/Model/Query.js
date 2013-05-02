var racer = require('../racer');
var Model = require('./index');

module.exports = Query;

racer.on('Model:init', function(model) {
  model._queries = new Queries;
});

Model.prototype.query = function(collectionName, sourceQuery, source) {
  var query = this._queries.get(collectionName, sourceQuery, source);
  if (query) return query;
  query = new Query(this, collectionName, sourceQuery, source);
  this._queries.add(query);
  return query;
};

function QueriesMap() {}

function Queries() {
  this.map = new QueriesMap;
}
Queries.prototype.add = function(query) {
  this.map[query.hash] = query;
};
Queries.prototype.remove = function(query) {
  delete this.map[query.hash];
};
Queries.prototype.get = function(collectionName, sourceQuery, source) {
  var hash = queryHash(collectionName, sourceQuery, source);
  return this.map[hash];
};
Queries.prototype.toJSON = function() {
  var out = [];
  for (var hash in this.map) {
    var query = this.map[hash];
    if (query.subscriptionCount) out.push(query.serialize());
  }
  return out;
};

function Query(model, collectionName, sourceQuery, source) {
  this.model = model;
  this.collectionName = collectionName;
  this.sourceQuery = sourceQuery;
  this.source = source;
  this.hash = queryHash(collectionName, sourceQuery, source);
  this.shareQuery = model.shareConnection.createQuery(collectionName, sourceQuery, source);
  this.subscriptionCount = 0;
}

Query.prototype.reinit = function(subscriptionCount, cb) {
  this.subscriptionCount = subscriptionCount;
  subscribe(this, cb);
};

Query.prototype.subscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  if (this.subscriptionCount++) {
    this.shareQuery.whenReady(function() {
      cb();
    });
    return;
  }

  this.shareQuery.autoFetch = true;
  subscribe(this, cb);
};

Query.prototype.setResults = function(results) {
  var ids = [];
  for (var i = 0; i < results.length; i++) {
    var doc = results[i];
    ids.push(doc.name);
  }
  var value = new QueryResults(ids);
  this.model._set(['_$queries', this.hash], value);
};

Query.prototype.ref = function(from) {
  var idsPath = '_$queries.' + this.hash + '.idsPath';
  this.model.refList(from, this.collectionName, idsPath);
}

function QueryResults(ids) {
  this.ids = ids;
  this.list = null;
}

function subscribe(query, cb) {
  query.shareQuery.subscribe();
  // TODO: this.shareQuery.on('error', cb);
  query.shareQuery.whenReady(function() {
    var results = query.shareQuery.results;
    query.setResults(results);
    for (var i = 0; i < results.length; i++) {
      var doc = results[i];
      query.model.subscribeDoc(doc.collection, doc.name);
    }
    cb();
  });
}

Query.prototype.unsubscribe = function() {

};

Query.prototype.serialize = function() {
  return [this.collectionName, this.sourceQuery, this.source, this.subscriptionCount];
};

function queryHash(collectionName, sourceQuery, source) {
  var args = [collectionName, sourceQuery, source];
  return JSON.stringify(args).replace(/\./g, '*');
}
