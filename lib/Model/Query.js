var util = require('../util');
var Model = require('./Model');
var arrayDiff = require('arraydiff');

module.exports = Query;

Model.INITS.push(function(model) {
  model.root._queries = new Queries();
  if (model.root.fetchOnly) return;
  model.on('all', function(segments) {
    var collectionName = segments[0];
    var map = model.root._queries.collections[collectionName];
    if (!map) return;
    for (var hash in map) {
      var query = map[hash];
      if (query.isPathQuery && query.shareQuery && util.mayImpact(query.expression, segments)) {
        var ids = pathIds(model, query.expression);
        query._setResultIds(ids);
      }
    }
  });
});

Model.prototype.query = function(collectionName, expression, source) {
  if (typeof expression.path === 'function' || typeof expression !== 'object') {
    expression = this._splitPath(expression);
  }
  var query = this.root._queries.get(collectionName, expression, source);
  if (query) return query;
  query = new Query(this, collectionName, expression, source);
  this.root._queries.add(query);
  return query;
};

// Called during initialization of the bundle on page load.
Model.prototype._initQueries = function(items) {
  var queries = this.root._queries;
  for (var i = 0; i < items.length; i++) {
    var item = items[i];
    var counts = item[0];
    var collectionName = item[1];
    var expression = item[2];
    var ids = item[3] || [];
    var snapshots = item[4] || [];
    var versions = item[5] || [];
    var source = item[6];
    var extra = item[7];
    var query = new Query(this, collectionName, expression, source);
    queries.add(query);

    query._addMapIds(ids);
    this._set(query.idsSegments, ids);

    // This is a bit of a hack, but it should be correct. Given that queries
    // are initialized first, the ids path is probably not set yet, but it will
    // be used to generate the query. Therefore, we assume that the value of
    // path will be the ids that the query results were on the server. There
    // are probably some really odd edge cases where this doesn't work, and
    // a more correct thing to do would be to get the actual value for the
    // path before creating the query subscription. This feature should
    // probably be rethought.
    if (query.isPathQuery && expression.length > 0 && this._isLocal(expression[0])) {
      this._setNull(expression, ids.slice());
    }

    query._setExtra(extra);

    for (var j = 0; j < snapshots.length; j++) {
      var snapshot = snapshots[j];
      if (!snapshot) continue;
      var id = ids[j];
      var version = versions[j];
      var data = {data: snapshot, v: version, type: 'json0'};
      this.getOrCreateDoc(collectionName, id, data);
    }

    for (var j = 0; j < counts.length; j++) {
      var count = counts[j];
      var subscribed = count[0] || 0;
      var fetched = count[1] || 0;
      var contextId = count[2];
      if (contextId) query.model.setContext(contextId);
      while (subscribed--) {
        query.subscribe();
      }
      query.fetchCount += fetched;
      while (fetched--) {
        query.model._context.fetchQuery(query);
      }
    }
  }
};

function Queries() {
  // Map is a flattened map of queries by hash. Currently used in contexts
  this.map = {};
  // Collections is a nested map of queries by collection then hash
  this.collections = {};
}
Queries.prototype.add = function(query) {
  this.map[query.hash] = query;
  var collection = this.collections[query.collectionName] ||
    (this.collections[query.collectionName] = {});
  collection[query.hash] = query;
};
Queries.prototype.remove = function(query) {
  delete this.map[query.hash];
  var collection = this.collections[query.collectionName];
  if (!collection) return;
  delete collection[query.hash];
  // Check if the collection still has any keys
  for (var key in collection) return;
  delete this.collections[collection];
};
Queries.prototype.get = function(collectionName, expression, source) {
  var hash = queryHash(collectionName, expression, source);
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

function Query(model, collectionName, expression, source) {
  this.model = model.pass({$query: this});
  this.collectionName = collectionName;
  this.expression = expression;
  this.source = source;
  this.hash = queryHash(collectionName, expression, source);
  this.segments = ['$queries', this.hash];
  this.idsSegments = ['$queries', this.hash, 'ids'];
  this.extraSegments = ['$queries', this.hash, 'extra'];
  this.isPathQuery = Array.isArray(expression);

  this._pendingSubscribeCallbacks = [];

  // These are used to help cleanup appropriately when calling unsubscribe and
  // unfetch. A query won't be fully cleaned up until unfetch and unsubscribe
  // are called the same number of times that fetch and subscribe were called.
  this.subscribeCount = 0;
  this.fetchCount = 0;

  this.created = false;
  this.shareQuery = null;

  // idMap is checked in maybeUnload to see if the query is currently holding
  // a reference to an id in its results set. This map is duplicative of the
  // actual results id list stored in the model, but we are maintaining it,
  // because otherwise maybeUnload would be looping through the entire results
  // set of each query on the same collection for every doc checked
  //
  // Map of id -> true
  this.idMap = {};
}

Query.prototype.create = function() {
  this.created = true;
  this.model.root._queries.add(this);
};

Query.prototype.destroy = function() {
  var ids = this.getIds();
  this.created = false;
  if (this.shareQuery) {
    this.shareQuery.destroy();
    this.shareQuery = null;
  }
  this.model.root._queries.remove(this);
  this.idMap = {};
  this.model._del(this.segments);
  this._maybeUnloadDocs(ids);
};

Query.prototype.sourceQuery = function() {
  if (this.isPathQuery) {
    var ids = pathIds(this.model, this.expression);
    return {_id: {$in: ids}};
  }
  return this.expression;
};

Query.prototype.fetch = function(cb) {
  cb = this.model.wrapCallback(cb);
  this.model._context.fetchQuery(this);

  this.fetchCount++;

  if (!this.created) this.create();

  var shareDocs = collectionShareDocs(this.model, this.collectionName);
  var options = {docMode: 'fetch', knownDocs: shareDocs};
  if (this.source) options.source = this.source;

  var query = this;
  function fetchCb(err, results, extra) {
    if (err) return cb(err);
    query._setExtra(extra);
    query._setResults(results);
    cb();
  }
  var shareQuery = this.model.root.shareConnection.createFetchQuery(
    this.collectionName,
    this.sourceQuery(),
    options,
    fetchCb
  );
  shareQuery.on('error', function(err) {
    query.model._emitError(err, query.hash);
  });
  return this;
};

Query.prototype.subscribe = function(cb) {
  cb = this.model.wrapCallback(cb);
  this.model._context.subscribeQuery(this);

  if (this.subscribeCount++) {
    var query = this;
    process.nextTick(function() {
      var data = query.model._get(query.segments);
      if (data) {
        cb();
      } else {
        query._pendingSubscribeCallbacks.push(cb);
      }
    });
    return this;
  }

  if (!this.created) this.create();

  // When doing server-side rendering, we actually do a fetch the first time
  // that subscribe is called, but keep track of the state as if subscribe
  // were called for proper initialization in the client
  var shareDocs = collectionShareDocs(this.model, this.collectionName);
  var options = {docMode: 'sub', knownDocs: shareDocs};
  if (this.source) options.source = this.source;

  if (this.model.root.fetchOnly) {
    this._shareFetchedSubscribe(options, cb);
  } else {
    this._shareSubscribe(options, cb);
  }

  return this;
};

Query.prototype._shareFetchedSubscribe = function(options, cb) {
  var query = this;
  function fetchedSubscribeCb(err, results, extra) {
    if (err) return query._flushSubscribeCallbacks(cb, err);
    query._setExtra(extra);
    query._setResults(results);
    query._flushSubscribeCallbacks(cb);
  }
  options.docMode = 'fetch';
  var shareQuery = this.model.root.shareConnection.createFetchQuery(
    this.collectionName,
    this.sourceQuery(),
    options,
    fetchedSubscribeCb
  );
  shareQuery.on('error', function(err) {
    query.model._emitError(err, query.hash);
  });
};

Query.prototype._shareSubscribe = function(options, cb) {
  var query = this;
  function subscribeCb(err, results, extra) {
    if (err) return query._flushSubscribeCallbacks(cb, err);
    query._setExtra(extra);
    // Results are not set, since a change event will already
    // have been emitted with the same results
    query._flushSubscribeCallbacks(cb);
  }
  // Sanity check, though this shouldn't happen
  if (this.shareQuery) {
    this.shareQuery.destroy();
  }
  this.shareQuery = this.model.root.shareConnection.createSubscribeQuery(
    this.collectionName,
    this.sourceQuery(),
    options,
    subscribeCb
  );
  this.shareQuery.on('insert', function(shareDocs, index) {
    var ids = resultsIds(shareDocs);
    query._addMapIds(ids);
    query.model._insert(query.idsSegments, index, ids);
  });
  this.shareQuery.on('remove', function(shareDocs, index) {
    var ids = resultsIds(shareDocs);
    query._removeMapIds(ids);
    query.model._remove(query.idsSegments, index, shareDocs.length);
  });
  this.shareQuery.on('move', function(shareDocs, from, to) {
    query.model._move(query.idsSegments, from, to, shareDocs.length);
  });
  this.shareQuery.on('change', function(shareDocs) {
    query._setResults(shareDocs);
  });
  this.shareQuery.on('extra', function(extra) {
    query.model._setDiffDeep(query.extraSegments, extra);
  });
  this.shareQuery.on('error', function(err) {
    query.model._emitError(err, query.hash);
  });
};

Query.prototype._removeMapIds = function(ids) {
  for (var i = ids.length; i--;) {
    var id = ids[i];
    delete this.idMap[id];
  }
  // Technically this isn't quite right and we might not wait the full unload
  // delay if someone else calls maybeUnload for the same doc id. However,
  // it is a lot easier to implement than delaying the removal until later and
  // dealing with adds that might happen in the meantime. This will probably
  // work to avoid thrashing subscribe/unsubscribe in expected cases
  if (this.model.root.unloadDelay) {
    var query = this;
    setTimeout(function() {
      query._maybeUnloadDocs(ids);
    }, this.model.root.unloadDelay);
    return;
  }
  this._maybeUnloadDocs(ids);
};
Query.prototype._addMapIds = function(ids) {
  for (var i = ids.length; i--;) {
    var id = ids[i];
    this.idMap[id] = true;
  }
};
Query.prototype._diffMapIds = function(ids) {
  var addedIds = [];
  var removedIds = [];
  var newMap = {};
  for (var i = ids.length; i--;) {
    var id = ids[i];
    newMap[id] = true;
    if (this.idMap[id]) continue;
    addedIds.push(id);
  }
  for (var id in this.idMap) {
    if (newMap[id]) continue;
    removedIds.push(id);
  }
  if (addedIds.length) this._addMapIds(addedIds);
  if (removedIds.length) this._removeMapIds(removedIds);
};
Query.prototype._setExtra = function(extra) {
  if (extra === undefined) return;
  this.model._setDiffDeep(this.extraSegments, extra);
};
Query.prototype._setResults = function(results) {
  var ids = resultsIds(results);
  this._setResultIds(ids);
};
Query.prototype._setResultIds = function(ids) {
  this._diffMapIds(ids);
  this.model._setArrayDiff(this.idsSegments, ids);
};
Query.prototype._maybeUnloadDocs = function(ids) {
  for (var i = 0; i < ids.length; i++) {
    var id = ids[i];
    this.model._maybeUnloadDoc(this.collectionName, id);
  }
};

// Flushes `_pendingSubscribeCallbacks`, calling each callback in the array,
// with an optional error to pass into each. `_pendingSubscribeCallbacks` will
// be empty after this runs.
Query.prototype._flushSubscribeCallbacks = function(cb, err) {
  cb(err);
  var pendingCallback;
  while (pendingCallback = this._pendingSubscribeCallbacks.shift()) {
    pendingCallback(err);
  }
};

Query.prototype.unfetch = function(cb) {
  cb = this.model.wrapCallback(cb);
  this.model._context.unfetchQuery(this);

  // No effect if the query is not currently fetched
  if (!this.fetchCount) {
    cb();
    return this;
  }

  var query = this;
  if (this.model.root.unloadDelay) {
    setTimeout(finishUnfetchQuery, this.model.root.unloadDelay);
  } else {
    finishUnfetchQuery();
  }
  function finishUnfetchQuery() {
    var count = --query.fetchCount;
    if (count) return cb(null, count);
    // Cleanup when no fetches or subscribes remain
    if (!query.subscribeCount) query.destroy();
    cb(null, 0);
  }
  return this;
};

Query.prototype.unsubscribe = function(cb) {
  cb = this.model.wrapCallback(cb);
  this.model._context.unsubscribeQuery(this);

  // No effect if the query is not currently subscribed
  if (!this.subscribeCount) {
    cb();
    return this;
  }

  var query = this;
  if (this.model.root.unloadDelay) {
    setTimeout(finishUnsubscribeQuery, this.model.root.unloadDelay);
  } else {
    finishUnsubscribeQuery();
  }
  function finishUnsubscribeQuery() {
    var count = --query.subscribeCount;
    if (count) return cb(null, count);

    if (query.shareQuery) {
      query.shareQuery.destroy();
      query.shareQuery = null;
    }

    unsubscribeQueryCallback();
  }
  function unsubscribeQueryCallback(err) {
    if (err) return cb(err);
    // Cleanup when no fetches or subscribes remain
    if (!query.fetchCount) query.destroy();
    cb(null, 0);
  }
  return this;
};

Query.prototype.get = function() {
  var results = [];
  var data = this.model._get(this.segments);
  if (!data) {
    console.warn('You must fetch or subscribe to a query before getting its results.');
    return results;
  }
  var ids = data.ids;
  if (!ids) return results;

  var collection = this.model.getCollection(this.collectionName);
  for (var i = 0, l = ids.length; i < l; i++) {
    var id = ids[i];
    var doc = collection && collection.docs[id];
    results.push(doc && doc.get());
  }
  return results;
};

Query.prototype.getIds = function() {
  return this.model._get(this.idsSegments) || [];
};

Query.prototype.getExtra = function() {
  return this.model._get(this.extraSegments);
};

Query.prototype.ref = function(from) {
  var idsPath = this.idsSegments.join('.');
  return this.model.refList(from, this.collectionName, idsPath);
};

Query.prototype.refIds = function(from) {
  var idsPath = this.idsSegments.join('.');
  return this.model.root.ref(from, idsPath);
};

Query.prototype.refExtra = function(from, relPath) {
  var extraPath = this.extraSegments.join('.');
  if (relPath) extraPath += '.' + relPath;
  return this.model.root.ref(from, extraPath);
};

Query.prototype.serialize = function() {
  var ids = this.getIds();
  var collection = this.model.getCollection(this.collectionName);
  var snapshots, versions;
  if (collection) {
    snapshots = [];
    versions = [];
    for (var i = 0; i < ids.length; i++) {
      var id = ids[i];
      var doc = collection.docs[id];
      if (doc) {
        snapshots.push(doc.shareDoc.snapshot);
        versions.push(doc.shareDoc.version);
        collection.remove(id);
      } else {
        snapshots.push(0);
        versions.push(0);
      }
    }
  }
  var counts = [];
  var contexts = this.model.root._contexts;
  for (var key in contexts) {
    var context = contexts[key];
    var subscribed = context.subscribedQueries[this.hash] || 0;
    var fetched = context.fetchedQueries[this.hash] || 0;
    if (subscribed || fetched) {
      if (key !== 'root') {
        counts.push([subscribed, fetched, key]);
      } else if (fetched) {
        counts.push([subscribed, fetched]);
      } else {
        counts.push([subscribed]);
      }
    }
  }
  var serialized = [
    counts
  , this.collectionName
  , this.expression
  , ids
  , snapshots
  , versions
  , this.source
  , this.getExtra()
  ];
  while (serialized[serialized.length - 1] == null) {
    serialized.pop();
  }
  return serialized;
};

function queryHash(collectionName, expression, source) {
  var args = [collectionName, expression, source];
  return JSON.stringify(args).replace(/\./g, '|');
}

function resultsIds(results) {
  var ids = [];
  for (var i = 0; i < results.length; i++) {
    var shareDoc = results[i];
    ids.push(shareDoc.name);
  }
  return ids;
}

function pathIds(model, segments) {
  var value = model._get(segments);
  return (typeof value === 'string') ? [value] :
    (Array.isArray(value)) ? value.slice() : [];
}

function collectionShareDocs(model, collectionName) {
  var collection = model.getCollection(collectionName);
  if (!collection) return;

  var results = [];
  for (var name in collection.docs) {
    results.push(collection.docs[name].shareDoc);
  }

  return results;
}
