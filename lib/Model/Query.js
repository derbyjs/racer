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
    query.create();
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

  this.created = false;
  this.shareQuery = null;
}

Query.prototype.create = function() {
  this.created = true;
  this.model._queries.add(this);
};

Query.prototype.destroy = function() {
  this.created = false;
  if (this.shareQuery) this.shareQuery.destroy();
  this.shareQuery = null;
  this.model._queries.remove(this);
  this.model._del(this.segments);
};

Query.prototype.fetch = function(cb) {
  if (!cb) cb = this.model._defaultCallback;
  this.fetchCount++;

  if (!this.created) this.create();

  var query = this;
  var model = this.model;
  var options = {autoFetch: true};

  model.shareConnection.createFetchQuery(
    this.collectionName, this.sourceQuery, options, function(err, results) {
      if (err) return cb(err);
      // Keep track of the ids at fetch time for use in unfetch
      var ids = resultsIds(results);
      query.fetchIds.push(ids.slice());
      // Update the results ids
      model._setDiff(query.segments, ids);
      if (!ids.length) return;
      // Call fetchDoc for each document returned so that the proper load events
      // and internal counts are maintained. However, specify that we already
      // loaded the documents as part of the query, since we don't want to
      // actually fetch the documents again
      var alreadyLoaded = true;
      var group = util.asyncGroup(cb);
      for (var i = 0; i < ids.length; i++) {
        model.fetchDoc(query.collectionName, ids[i], group(), alreadyLoaded);
      }
    }
  );
};

Query.prototype.subscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;
  this.subscribeCount++;

  if (!this.created) this.create();

  var query = this;
  var options = {autoFetch: true};

  // When doing server-side rendering, we actually do a fetch the first time
  // that subscribe is called, but keep track of the state as if subscribe
  // were called for proper initialization in the client
  if (this.model.fetchOnly) {
    this.model.shareConnection.createFetchQuery(
      this.collectionName, this.sourceQuery, options, function(err, results) {
        if (err) return cb(err);
        query._onChange(results);
        cb();
      }
    );
    return;
  }
  this.shareQuery = this.model.shareConnection.createSubscribeQuery(
    this.collectionName, this.sourceQuery, options, function(err) {
      if (err) return cb(err);
      cb();
    }
  );
  this.shareQuery.on('insert', function(shareDoc, index) {
    query._onInsert(shareDoc, index);
  });
  this.shareQuery.on('remove', function(shareDoc, index) {
    query._onRemove(shareDoc, index);
  });
  this.shareQuery.on('change', function(results, previous) {
    query._onChange(results, previous);
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

  if (--this.fetchCount < 1) {
    // Cleanup when no fetches or subscribes remain
    if (this.subscribeCount < 1) this.destroy();
  }

  cb(null, this.fetchCount);
};

Query.prototype.unsubscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  // No effect if the query is not currently subscribed
  if (this.subscribeCount < 1) return cb();

  if (--this.subscribeCount > 1) {
    // If there are remaining subscriptions, just call back with count
    cb(null, this.subscribeCount);
    return;
  }

  // If there is only one remaining subscription, actually unsubscribe
  var query = this;
  if (this.model.fetchOnly) {
    unsubscribeQueryCallback();
  } else {
    if (!this.shareQuery) return unsubscribeQueryCallback();
    var results = this.shareQuery.results;
    this.shareQuery.destroy();
    this.shareQuery = null;
    // Also unsubscribe all documents that this query currently has in results
    if (!results.length) return unsubscribeQueryCallback();
    var group = util.asyncGroup(unsubscribeQueryCallback);
    for (var i = 0; i < results.length; i++) {
      var shareDoc = results[i];
      this.model.unsubscribeDoc(this.collectionName, shareDoc.name, group());
    }
  }
  function unsubscribeQueryCallback(err) {
    // Cleanup when no fetches or subscribes remain
    if (query.fetchCount < 1) query.destroy();
    if (err) return cb(err);
    cb(null, 0);
  }
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
Query.prototype._onChange = function(results, previous) {
  // Get the new and previous list of ids when the entire results set changes
  var ids = resultsIds(results);
  var previousIds = previous && resultsIds(previous);

  // Diff the new and previous list of ids, subscribing to documents for
  // inserted ids and unsubscribing from documents for removed ids
  var diff = (previousIds) ?
    arrayDiff(previousIds, ids) :
    [new arrayDiff.InsertDiff(0, ids)];
  for (var i = 0; i < diff.length; i++) {
    var item = diff[i];
    if (item instanceof arrayDiff.InsertDiff) {
      // Subscribe to the document for each inserted id
      for (var idIndex = 0; idIndex < ids.length; idIndex++) {
        this.model.subscribeDoc(this.collectionName, ids[idIndex]);
      }
    } else if (item instanceof arrayDiff.RemoveDiff) {
      // Unsubscribe from the document for each removed id
      for (var idIndex = 0; idIndex < ids.length; idIndex++) {
        this.model.unsubscribeDoc(this.collectionName, ids[idIndex]);
      }
    }
    // Moving doesn't change document subscriptions, so that is ignored
  }

  // The results are updated via a different diff, since they might already
  // have a value from a fetch or previous shareQuery instance
  model._setDiff(this.segments, results);
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
