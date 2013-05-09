var util = require('../util');
var Model = require('./index');
var arrayDiff = require('./arrayDiff');

module.exports = Query;

Model.INITS.push(function(model) {
  model._queries = new Queries;
  if (model.fetchOnly) return;
  model.on('all', function(segments) {
    var map = model._queries.map;
    for (var hash in map) {
      var query = map[hash];
      if (query.isPathQuery && util.mayImpact(query.sourceQuery, segments)) {
        var ids = pathIds(model, query.sourceQuery);
        query._onChange(ids);
      }
    }
  });
});

Model.prototype.query = function(collectionName, sourceQuery, source) {
  if (typeof sourceQuery.path === 'function' || typeof sourceQuery !== 'object') {
    sourceQuery = this._splitPath(sourceQuery);
  }
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
    if (query.subscribeCount && !query.isPathQuery) {
      initSubscribed(this, query);
    }
  }
};
function initSubscribed(model, query) {
  // Cache the results of the query in the model at init time
  var ids = model._get(query.segments).slice();
  // TODO: Ideally we would have another fetch mode that doesn't refetch
  // initially, but does autoFetch for all new documents that are added
  var options = {autoFetch: true};
  query._shareSubscribe(options, function(err) {
    if (err) return model.emit('error', err);
    // Offset the initial subscribes, which will now have been resubscribed
    // again in the 'change' event after subscription
    for (var i = 0; i < ids.length; i++) {
      model.unsubscribeDoc(query.collectionName, ids[i]);
    }
  });
}

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
  this.isPathQuery = Array.isArray(sourceQuery);

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

  if (this.isPathQuery) {
    var ids = pathIds(this.model, this.sourceQuery);
    finishFetch(ids);
    return;
  } else {
    model.shareConnection.createFetchQuery(
      this.collectionName, this.sourceQuery, options, function(err, results) {
        if (err) return cb(err);
        var ids = resultsIds(results);
        finishFetch(ids);
      }
    );
  }

  function finishFetch(ids) {
    // Keep track of the ids at fetch time for use in unfetch
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
};

Query.prototype.subscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;

  if (this.subscribeCount++) return;

  if (!this.created) this.create();
  var query = this;

  if (this.isPathQuery) {
    var ids = pathIds(this.model, this.sourceQuery);
    query._onChange(ids);
    cb();
    return;
  }

  // When doing server-side rendering, we actually do a fetch the first time
  // that subscribe is called, but keep track of the state as if subscribe
  // were called for proper initialization in the client
  var options = {autoFetch: true};
  if (this.model.fetchOnly) {
    this.model.shareConnection.createFetchQuery(
      this.collectionName, this.sourceQuery, options, function(err, results) {
        if (err) return cb(err);
        var ids = resultsIds(results);
        query._onChange(ids);
        cb();
      }
    );
    return;
  }
  this.shareSubscribe(options, cb);
};

Query.prototype._shareSubscribe = function(options, cb) {
  this.shareQuery = this.model.shareConnection.createSubscribeQuery(
    this.collectionName, this.sourceQuery, options, cb
  );
  var query = this;
  this.shareQuery.on('insert', function(shareDoc, index) {
    query._onInsert(shareDoc, index);
  });
  this.shareQuery.on('remove', function(shareDoc, index) {
    query._onRemove(shareDoc, index);
  });
  this.shareQuery.on('change', function(results, previous) {
    // Get the new and previous list of ids when the entire results set changes
    var ids = resultsIds(results);
    var previousIds = previous && resultsIds(previous);
    query._onChange(ids, previousIds);
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
    if (this.isPathQuery) {
      var ids = pathIds(this.model, this.sourceQuery);
    } else {
      if (!this.shareQuery) return unsubscribeQueryCallback();
      var ids = resultsIds(this.shareQuery.results);
      this.shareQuery.destroy();
      this.shareQuery = null;
    }
    // Also unsubscribe all documents that this query currently has in results
    if (!ids.length) return unsubscribeQueryCallback();
    var group = util.asyncGroup(unsubscribeQueryCallback);
    for (var i = 0; i < ids.length; i++) {
      this.model.unsubscribeDoc(this.collectionName, ids[i], group());
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
Query.prototype._onChange = function(ids, previousIds) {
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
  this.model._setDiff(this.segments, ids);
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

function pathIds(model, segments) {
  var value = model._get(segments);
  return (typeof value === 'string') ? [value] :
    (Array.isArray(value)) ? value.slice() : [];
}
