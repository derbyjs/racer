var racer = require('../racer');
var Model = require('./index');
var util = require('../util');
var arrayDiff = require('./arrayDiff');

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
Model.prototype._initQueries = function(items) {
  for (var i = 0; i < items.length; i++) {
    var item = items[i];
    var query = new Query(this, item[0], item[1], item[2], item[3]);
    this._queries.add(query);
    query.shareQuery.subscribe(this._defaultCallback);
  }
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

function Query(model, collectionName, sourceQuery, source, subscriptionCount) {
  this.model = model;
  this.collectionName = collectionName;
  this.sourceQuery = sourceQuery;
  this.source = source;
  this.hash = queryHash(collectionName, sourceQuery, source);
  this.segments = ['_$queries', this.hash];
  this.subscriptionCount = subscriptionCount || 0;

  this.shareQuery = model.shareConnection.createQuery(collectionName, sourceQuery, source);
  var query = this;
  this.shareQuery.on('insert', function(shareDoc, index) {
    query._onInsert(shareDoc, index);
  });
  this.shareQuery.on('remove', function(shareDoc, index) {
    query._onRemove(shareDoc, index);
  });
  this.shareQuery.on('change', function(results) {
    query._onChange(results);
  });
}

Query.prototype.subscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  if (this.subscriptionCount++) {
    // TODO: just call subscribe multiple times when it supports callback
    this.shareQuery.whenReady(function() {
      cb();
    });
    return;
  }

  this.shareQuery.autoFetch = true;
  this.shareQuery.subscribe(cb);

  // TODO: remove when subscribe supports callback & change event is fired
  var query = this;
  this.shareQuery.once('ready', function(results) {
    query._onChange(results);
    cb();
  });
};

Query.prototype.unsubscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  // No effect if the query is not currently subscribed
  if (this.subscriptionCount < 1) return cb();

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
      this.model.unsubscribeDoc(this.collectionName, shareDoc.name, group.add());
    }
    // Delete the query results
    model._del(this.segments);
    return;
  }

  // If there are other remaining subscriptions, only decrement the count and
  // callback with how many subscriptions are remaining
  cb(null, --this.subscriptionCount);
};

Query.prototype._onInsert = function(shareDoc, index) {
  var id = shareDoc.name;
  this.model._insert(this.segments, index, [id]);
  this.model.subscribeDoc(this.collectionName, id);
};
Query.prototype._onRemove = function(shareDoc, index) {
  var id = shareDoc.name;
  this.model._remove(this.segments, index, 1);
  this.model.unsubscribeDoc(this.collectionName, id);
};
Query.prototype._onChange = function(results) {
  // Get the new and previous list of ids when the entire results set changes
  var previousIds = this.model._get(this.segments);
  var ids = [];
  for (var i = 0; i < results.length; i++) {
    var shareDoc = results[i];
    ids.push(shareDoc.name);
  }
  // Diff the new and previous list of ids, subscribing to documents for
  // inserted ids and unsubscribing from documents for removed ids
  var diff = (previousIds) ?
    arrayDiff(previousIds, ids) :
    [new arrayDiff.InsertDiff(0, ids)];
  for (var i = 0; i < diff.length; i++) {
    var item = diff[i];
    if (item instanceof arrayDiff.InsertDiff) {
      var ids = item.values;
      this.model._insert(this.segments, item.index, ids);
      // Subscribe to the document for each inserted id
      for (var idIndex = 0; idIndex < ids.length; idIndex++) {
        this.model.subscribeDoc(this.collectionName, ids[idIndex]);
      }
    } else if (item instanceof arrayDiff.RemoveDiff) {
      var ids = model._remove(this.segments, item.index, item.howMany);
      // Unsubscribe from the document for each removed id
      for (var idIndex = 0; idIndex < ids.length; idIndex++) {
        this.model.unsubscribeDoc(this.collectionName, ids[idIndex]);
      }
    } else if (item instanceof arrayDiff.MoveDiff) {
      this.model._move(this.segments, item.from, item.to, item.howMany);
      // Moving doesn't change document subscriptions
    }
  }  
};

Query.prototype.ref = function(from) {
  var idsPath = '_$queries.' + this.hash;
  this.model.refList(from, this.collectionName, idsPath);
};

Query.prototype.serialize = function() {
  return [this.collectionName, this.sourceQuery, this.source, this.subscriptionCount];
};

function queryHash(collectionName, sourceQuery, source) {
  var args = [collectionName, sourceQuery, source];
  return JSON.stringify(args).replace(/\./g, '*');
}
