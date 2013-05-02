var racer = require('../racer');
var Model = require('./index');
var util = require('../util');

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
  this.segments = ['_$queries', this.hash];
  this.subscriptionCount = 0;

  this.shareQuery = model.shareConnection.createQuery(collectionName, sourceQuery, source);
  var query = this;
  this.shareQuery.on('insert', function(shareDoc, index) {
    query._onInsert(index, shareDoc);
  });
  this.shareQuery.on('remove', function(shareDoc, index) {
    query._onRemove(index);
  });
  this.shareQuery.on('change', function(results) {
    query._onChange(results);
  });
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

Query.prototype.unsubscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  // No effect if the query is not currently subscribed
  if (!this.subscriptionCount) return cb();

  // If there is only one remaining subscription, actually unsubscribe
  if (this.subscriptionCount === 1) {
    this.subscriptionCount = 0;
    // Callback when the query and all of its docs have been unsubscribed
    var group = new util.AsyncGroup(function(err) {
      if (err) return cb(err);
      cb(null, 0);
    });
    this.shareQuery.unsubscribe(group.add());
    // Also unsubscribe all documents that this query currently has in results
    var results = this.shareQuery.results;
    for (var i = 0; i < results.length; i++) {
      var shareDoc = results[i];
      model.unsubscribeDoc(this.collectionName, shareDoc.name, group.add());
    }
  }

  // If there are other remaining subscriptions, only decrement the count and
  // callback with how many subscriptions are remaining
  var count = --this.subscriptionCount;
  cb(null, count);
};

Query.prototype._onInsert = function(index, shareDoc) {
  this.model._insert(this.segments, index, [shareDoc.name]);
};
Query.prototype._onRemove = function(index) {
  this.model._remove(this.segments, index, 1);
};
Query.prototype._onChange = function(results) {
  var ids = [];
  for (var i = 0; i < results.length; i++) {
    var shareDoc = results[i];
    ids.push(shareDoc.name);
  }
  this.model._setDiff(this.segments, ids);
};

Query.prototype.ref = function(from) {
  var idsPath = '_$queries.' + this.hash;
  this.model.refList(from, this.collectionName, idsPath);
};

function subscribe(query, cb) {
  query.shareQuery.subscribe();
  // TODO: this.shareQuery.on('error', cb);
  query.shareQuery.whenReady(function() {
    var results = query.shareQuery.results;
    query._onChange(results);
    for (var i = 0; i < results.length; i++) {
      var doc = results[i];
      query.model.subscribeDoc(doc.collection, doc.name);
    }
    cb();
  });
}

Query.prototype.serialize = function() {
  return [this.collectionName, this.sourceQuery, this.source, this.subscriptionCount];
};

function queryHash(collectionName, sourceQuery, source) {
  var args = [collectionName, sourceQuery, source];
  return JSON.stringify(args).replace(/\./g, '*');
}
