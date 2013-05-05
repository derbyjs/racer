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
    var query = new Query(this, item[0], item[1], item[2], item[3], item[4], item[5]);
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
    if (query.subscribeCount || query.fetchCount) {
      out.push(query.serialize());
    }
  }
  return out;
};

function Query(model, collectionName, sourceQuery, source, subscribeCount, fetchCount, fetchIds) {
  this.model = model;
  this.collectionName = collectionName;
  this.sourceQuery = sourceQuery;
  this.source = source;
  this.hash = queryHash(collectionName, sourceQuery, source);
  this.segments = ['$queries', this.hash];

  // These are used to help cleanup appropriately when calling unsubscribe and
  // unfetch. A query won't be fully cleaned up until unfetch and unsubscribe
  // are called the same number of times that fetch and subscribe were called.
  this.subscribeCount = subscribeCount || 0;
  this.fetchCount = fetchCount || 0;
  // The list of ids at the time of each fetch is pushed onto fetchIds, so
  // that unfetchDoc can be called the same number of times as fetchDoc
  this.fetchIds = fetchIds || [];

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

Query.prototype.fetch = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  this.fetchCount++;

  var query = this;
  var model = this.model;
  this.shareQuery.autoFetch = true;
  this.shareQuery.fetch(function(err, results) {
    if (err) return cb(err);
    // Keep track of the ids at fetch time for use in unfetch
    var ids = resultsIds(results);
    query.fetchIds.push(ids.slice());
    // Update the results ids
    model.setDiff(query.segments, ids);
    // Call fetchDoc for each document returned so that the proper load events
    // and internal counts are maintained. However, specify that we already
    // loaded the documents as part of the query, since we don't want to
    // actually fetch the documents again
    var alreadyLoaded = true;
    var group = new util.AsyncGroup(cb);
    for (var i = 0; i < ids.length; i++) {
      model.fetchDoc(query.collectionName, ids[i], group.add(), alreadyLoaded);
    }
  });
};

Query.prototype.subscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  if (this.subscribeCount++) {
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

Query.prototype.unfetch = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  // No effect if the query is not currently fetched
  if (this.fetchCount < 1) return cb();

  var ids = this.fetchIds.shift() || [];
  for (var i = 0; i < ids.length; i++) {
    this.model.unfetchDoc(this.collectionName, ids[i]);
  }

  if (--this.fetchCount === 0) {
    // Delete the query results when no fetches or subscribes remain
    if (this.subscribeCount < 1) model._del(this.segments);
  }

  cb(null, this.fetchCount);
};

Query.prototype.unsubscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  // No effect if the query is not currently subscribed
  if (this.subscribeCount < 1) return cb();

  // If there is only one remaining subscription, actually unsubscribe
  if (--this.subscribeCount === 0) {
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
    // Delete the query results when no fetches or subscribes remain
    if (this.fetchCount < 1) model._del(this.segments);
    return;
  }

  // If there are remaining subscriptions, just call back with count
  cb(null, this.subscribeCount);
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
  var ids = resultsIds(results);
  
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

Query.prototype.get = function() {
  var ids = this.model._get(this.segments);
  if (!ids) return;
  var out = [];
  var collection = this.model.getCollection(this.collectionName);
  for (var i = 0; i < ids.length; i++) {
    var id = ids[i];
    var doc = collection && collection.docs[id];
    out.push(doc && doc.get());
  }
  return out;
};

Query.prototype.ref = function(from) {
  var idsPath = this.segments.join('.');
  this.model.refList(from, this.collectionName, idsPath);
};

Query.prototype.serialize = function() {
  return [
    this.collectionName
  , this.sourceQuery
  , this.source
  , this.subscribeCount
  , this.fetchCount
  , this.fetchIds
  ];
};

function queryHash(collectionName, sourceQuery, source) {
  var args = [collectionName, sourceQuery, source];
  return JSON.stringify(args).replace(/\./g, '*');
}

function resultsIds(results) {
  var ids = [];
  for (var i = 0; i < results.length; i++) {
    var shareDoc = results[i];
    ids.push(shareDoc.name);
  }
  return ids;
}
