var util = require('../util');
var Model = require('./index');
var arrayDiff = require('arraydiff');
var deepEquals = require('deep-is');

module.exports = Query;

Model.INITS.push(function(model) {
  model._queries = new Queries;
  if (model.fetchOnly) return;
  model.on('all', function(segments) {
    // Updated async, since this is likely the result of an operation that
    // includes creating the doc, and we would like that to happen before
    // sending the subscribe message
    process.nextTick(function() {
      var map = model._queries.map;
      for (var hash in map) {
        var query = map[hash];
        if (query.isPathQuery && query.shareQuery && util.mayImpact(query.expression, segments)) {
          var ids = pathIds(model, query.expression);
          var previousIds = model._get(query.idSegments);
          query._onChange(ids, previousIds);
        }
      }
    });
  });
});

/**
 * @param {String} collectionName
 * @param {Object} expression
 * @param {String} source
 * @return {Query}
 */
Model.prototype.query = function(collectionName, expression, source) {
  if (typeof expression.path === 'function' || typeof expression !== 'object') {
    expression = this._splitPath(expression);
  }
  var query = this._queries.get(collectionName, expression, source);
  if (query) return query;
  query = new Query(this, collectionName, expression, source);
  this._queries.add(query);
  return query;
};

/**
 * Called during initialization of the bundle on page load.
 * @param {Array} items
 * @param {Array} items[*]
 * @param {String} items[*][0] collectionName
 * @param {Object} items[*][1] expression
 * @param {String} items[*][2] source
 * @param {Number} items[*][3] subscribeCount
 * @param {Number} items[*][4] fetchCount
 * @param {Array}  items[*][5] fetchIds
 */
Model.prototype._initQueries = function(items) {
  for (var i = 0; i < items.length; i++) {
    var item = items[i];
    var query = new Query(this, item[0], item[1], item[2], item[3], item[4], item[5]);
    var count = query.fetchCount;
    while (count--) this.emit('fetchQuery', query, this._context);
    var count = query.subscribeCount;
    query.subscribeCount = 0;
    // TODO: Ideally we would have another fetch mode that doesn't refetch
    // initially, but does autoFetch for all new documents that are added
    while (count--) query.subscribe();
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

/**
 * @private
 * @constructor
 * @param {Model} model
 * @param {Object} collectionName
 * @param {Object} expression
 * @param {String} source (e.g., 'solr')
 * @param {Number} subscribeCount
 * @param {Number} fetchCount
 * @param {Array<Array<String>>} fetchIds
 */
function Query(model, collectionName, expression, source, subscribeCount, fetchCount, fetchIds) {
  this.model = model.pass({$query: this});
  this.collectionName = collectionName;
  this.expression = expression;
  this.source = source;
  this.hash = queryHash(collectionName, expression, source);
  this.segments = ['$queries', this.hash];
  this.idSegments = ['$queries', this.hash, 'ids'];
  this.extraSegments = ['$queries', this.hash, 'extra'];
  this.isPathQuery = Array.isArray(expression);

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
  if (this.shareQuery) {
    this.shareQuery.destroy();
    this.shareQuery = null;
  }
  this.model._queries.remove(this);
  this.model._del(this.segments);
};

Query.prototype.sourceQuery = function() {
  if (this.isPathQuery) {
    var ids = pathIds(this.model, this.expression);
    return {_id: {$in: ids}};
  }
  return this.expression;
};

/**
 * @param {Function} [cb] cb(err)
 */
Query.prototype.fetch = function(cb) {
  if (!cb) cb = this.model._defaultCallback;
  this.model.emit('fetchQuery', this, this.model._context);

  this.fetchCount++;

  if (!this.created) this.create();
  var query = this;

  var model = this.model;
  var options = {autoFetch: true};
  if (this.source) options.source = this.source;

  model.shareConnection.createFetchQuery(
    this.collectionName, this.sourceQuery(), options, fetchQueryCallback
  );
  function fetchQueryCallback(err, results, extra) {
    if (err) return cb(err);
    var ids = resultsIds(results);

    // Keep track of the ids at fetch time for use in unfetch
    query.fetchIds.push(ids.slice());
    // Update the results ids and extra
    model._setDiff(query.idSegments, ids);
    if (extra !== void 0) {
      model._setDiff(query.extraSegments, extra, {equal: deepEquals});
    }

    if (!ids.length) return cb();

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
  return this;
};

/**
 * Sets up a subscription to `this` query.
 * @param {Function} cb(err)
 */
Query.prototype.subscribe = function(cb) {
  if (!cb) cb = this.model._defaultCallback;
  this.model.emit('subscribeQuery', this, this.model._context);

  if (this.subscribeCount++) {
    process.nextTick(cb);
    return this;
  }

  if (!this.created) this.create();
  var query = this;

  // When doing server-side rendering, we actually do a fetch the first time
  // that subscribe is called, but keep track of the state as if subscribe
  // were called for proper initialization in the client
  var options = {autoFetch: true};
  if (this.source) options.source = this.source;

  if (!this.model.fetchOnly) {
    this._shareSubscribe(options, cb);
    return this;
  }

  var query = this;
  var model = this.model;
  model.shareConnection.createFetchQuery(
    this.collectionName, this.sourceQuery(), options, function(err, results, extra) {
      if (err) return cb(err);
      var ids = resultsIds(results);
      if (extra !== void 0) {
        model._setDiff(query.extraSegments, extra, {equal: deepEquals});
      }
      query._onChange(ids, null, cb);
    }
  );
  return this;
};

/**
 * @private
 * @param {Object} options
 * @param {String} [options.source]
 * @param {Boolean} [options.poll]
 * @param {Boolean} [options.autoFetch = false]
 * @param {Function} cb(err, results)
 */
Query.prototype._shareSubscribe = function(options, cb) {
  var query = this;
  var model = this.model;
  this.shareQuery = this.model.shareConnection.createSubscribeQuery(
    this.collectionName, this.sourceQuery(), options, function (err, results, extra) {
      if (err) return cb(err);
      var ids = resultsIds(results);
      if (extra !== void 0) {
        model._setDiff(query.extraSegments, extra, {equal: deepEquals});
      }
      query._onChange(ids, null, cb);
    }
  );
  var query = this;
  this.shareQuery.on('insert', function(shareDocs, index) {
    query._onInsert(shareDocs, index);
  });
  this.shareQuery.on('remove', function(shareDocs, index) {
    query._onRemove(shareDocs, index);
  });
  this.shareQuery.on('move', function(shareDocs, from, to) {
    query._onMove(shareDocs, from, to);
  });
  this.shareQuery.on('change', function(results, previous) {
    // Get the new and previous list of ids when the entire results set changes
    var ids = resultsIds(results);
    var previousIds = previous && resultsIds(previous);
    query._onChange(ids, previousIds);
  });
  this.shareQuery.on('extra', function (extra) {
    model._setDiff(query.extraSegments, extra, {equal: deepEquals});
  });
};

/**
 * @public
 * @param {Function} cb(err, newFetchCount)
 */
Query.prototype.unfetch = function(cb) {
  if (!cb) cb = this.model._defaultCallback;
  this.model.emit('unfetchQuery', this, this.model._context);

  // No effect if the query is not currently fetched
  if (!this.fetchCount) {
    cb();
    return this;
  }

  var ids = this.fetchIds.shift() || [];
  for (var i = 0; i < ids.length; i++) {
    this.model.unfetchDoc(this.collectionName, ids[i]);
  }

  var query = this;
  if (this.model.unloadDelay) {
    setTimeout(finishUnfetchQuery, this.model.unloadDelay);
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
  if (!cb) cb = this.model._defaultCallback;
  this.model.emit('unsubscribeQuery', this, this.model._context);

  // No effect if the query is not currently subscribed
  if (!this.subscribeCount) {
    cb();
    return this;
  }

  var query = this;
  if (this.model.unloadDelay) {
    setTimeout(finishUnsubscribeQuery, this.model.unloadDelay);
  } else {
    finishUnsubscribeQuery();
  }
  function finishUnsubscribeQuery() {
    var count = --query.subscribeCount;
    if (count) return cb(null, count);

    if (query.shareQuery) {
      var ids = resultsIds(query.shareQuery.results);
      query.shareQuery.destroy();
      query.shareQuery = null;
    }

    if (!query.model.fetchOnly && ids && ids.length) {
      // Unsubscribe all documents that this query currently has in results
      var group = util.asyncGroup(unsubscribeQueryCallback);
      for (var i = 0; i < ids.length; i++) {
        query.model.unsubscribeDoc(query.collectionName, ids[i], group());
      }
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

Query.prototype._onInsert = function(shareDocs, index) {
  var ids = [];
  for (var i = 0; i < shareDocs.length; i++) {
    var id = shareDocs[i].name;
    ids.push(id);
    this.model.subscribeDoc(this.collectionName, id);
  }
  this.model._insert(this.idSegments, index, ids);
};
Query.prototype._onRemove = function(shareDocs, index) {
  this.model._remove(this.idSegments, index, shareDocs.length);
  for (var i = 0; i < shareDocs.length; i++) {
    this.model.unsubscribeDoc(this.collectionName, shareDocs[i].name);
  }
};
Query.prototype._onMove = function(shareDocs, from, to) {
  this.model._move(this.idSegments, from, to, shareDocs.length);
};

Query.prototype._onChange = function(ids, previousIds, cb) {
  // Diff the new and previous list of ids, subscribing to documents for
  // inserted ids and unsubscribing from documents for removed ids
  var diff = (previousIds) ?
    arrayDiff(previousIds, ids) :
    [new arrayDiff.InsertDiff(0, ids)];

  // The results are updated via a different diff, since they might already
  // have a value from a fetch or previous shareQuery instance
  this.model._setDiff(this.idSegments, ids);

  var group = cb && util.asyncGroup(cb);
  var previousCopy = previousIds && previousIds.slice();
  for (var i = 0; i < diff.length; i++) {
    var item = diff[i];
    if (item instanceof arrayDiff.InsertDiff) {
      // Subscribe to the document for each inserted id
      var values = item.values;
      for (var j = 0; j < values.length; j++) {
        this.model.subscribeDoc(this.collectionName, values[j], cb && group());
      }
    } else if (item instanceof arrayDiff.RemoveDiff) {
      var values = previousCopy.splice(item.index, item.howMany);
      // Unsubscribe from the document for each removed id
      for (var j = 0; j < values.length; j++) {
        this.model.unsubscribeDoc(this.collectionName, values[j], cb && group());
      }
    }
    // Moving doesn't change document subscriptions, so that is ignored.
  }
  // Make sure that the callback gets called if the diff is empty or it
  // contains no inserts or removes
  cb && group()();
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
  return (data.extra === void 0) ?
    results :
    {results: results, extra: data.extra};
};

/**
 * Lazily creates or gets a ref to our resultset's results.
 */
Query.prototype.ref = function(from) {
  var idsPath = this.idSegments.join('.');
  return this.model.refList(from, this.collectionName, idsPath);
};

/**
 * Lazily creates or gets a ref to our resultset's extra data.
 */
Query.prototype.extraRef = function(from, relPath) {
  var extraPath = this.extraSegments.join('.') + (relPath ? '.' + relPath : '');
  return this.model.ref(from, extraPath);
};

Query.prototype.serialize = function() {
  return [
    this.collectionName
  , this.expression
  , this.source
  , this.subscribeCount
  , this.fetchCount
  , this.fetchIds
  ];
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
