import { type Context } from './contexts';
import { type Segments } from './types';
import { ChildModel, ErrorCallback, Model } from './Model';
import { CollectionMap } from './CollectionMap';
import { ModelData } from '.';
import type { Doc } from './Doc';
import type { Doc as ShareDBDoc } from 'sharedb';
import type { RemoteDoc } from './RemoteDoc';

var defaultType = require('sharedb/lib/client').types.defaultType;
var util = require('../util');
var promisify = util.promisify;

export type QueryOptions = string | { db: any };

interface QueryCtor {
  new (model: Model, collectionName: string, expression: any, options: QueryOptions): Query;
}

declare module './Model' {
  interface Model {
    query<T = {}>(collectionName: string, expression, options?: QueryOptions): Query;
    sanitizeQuery(expression): Query;

    _getOrCreateQuery(collectionName: string, expression, options: QueryOptions, QueryConstructor: QueryCtor): Query;
    _initQueries(items: any[]): void;
    _queries: Queries;
  }
}

Model.INITS.push(function(model) {
  model.root._queries = new Queries();
});

Model.prototype.query = function(collectionName: string, expression, options?: QueryOptions) {
  // DEPRECATED: Passing in a string as the third argument specifies the db
  // option for backward compatibility
  if (typeof options === 'string') {
    options = { db: options };
  }
  return this._getOrCreateQuery(collectionName, expression, options, Query);
};

/**
 * If an existing query is present with the same context, `collectionName`,
 * `expression`, and `options`, then returns the existing query; otherwise,
 * constructs and returns a new query using `QueryConstructor`.
 *
 * @param {string} collectionName
 * @param {*} expression
 * @param {*} options
 * @param {new (model: Model, collectionName: string, expression: any, options: any) => Query} QueryConstructor -
 *   constructor function for a Query, to create one if not already present on this model
 */
Model.prototype._getOrCreateQuery = function(collectionName, expression, options, QueryConstructor) {
  expression = this.sanitizeQuery(expression);
  var contextId = this._context.id;
  var query = this.root._queries.get(contextId, collectionName, expression, options);
  if (query) return query;
  query = new QueryConstructor(this, collectionName, expression, options);
  this.root._queries.add(query);
  return query;
};

// This method replaces undefined in query objects with null, because
// undefined properties are removed in JSON stringify. This can be dangerous
// in queries, where presenece of a property may indicate that it should be a
// filter and absence means that all values are accepted. We aren't checking
// for cycles, which aren't allowed in JSON, so this could throw a max call
// stack error
Model.prototype.sanitizeQuery = function(expression) {
  if (expression && typeof expression === 'object') {
    for (var key in expression) {
      if (expression.hasOwnProperty(key)) {
        var value = expression[key];
        if (value === undefined) {
          expression[key] = null;
        } else {
          this.sanitizeQuery(value);
        }
      }
    }
  }
  return expression;
};

// Called during initialization of the bundle on page load.
Model.prototype._initQueries = function(items: any[][]) {
  for (var i = 0; i < items.length; i++) {
    var item = items[i];
    const [countsList, collectionName, expression, results=[], options, extra] = item;
    // var countsList = item[0];
    // var collectionName = item[1];
    // var expression = item[2];
    // var results = item[3] || [];
    // var options = item[4];
    // var extra = item[5];
    const [counts] = countsList;
    // var counts = countsList[0];
    var [subscribed = 0, fetched = 0, contextId] = counts;
    // var subscribed = counts[0] || 0;
    // var fetched = counts[1] || 0;
    // var contextId = counts[2];

    var model = (contextId) ? this.context(contextId) : this;
    var query = model._getOrCreateQuery(collectionName, expression, options, Query);

    query._setExtra(extra);

    var ids = [];
    for (var resultIndex = 0; resultIndex < results.length; resultIndex++) {
      var result = results[resultIndex];
      if (typeof result === 'string') {
        ids.push(result);
        continue;
      }
      var data = result[0];
      var v = result[1];
      var id = result[2] || data.id;
      var type = result[3];
      ids.push(id);
      var snapshot = { data: data, v: v, type: type };
      this.getOrCreateDoc(collectionName, id, snapshot);
    }
    query._addMapIds(ids);
    this._set(query.idsSegments, ids);

    while (subscribed--) {
      query.subscribe();
    }
    query.fetchCount += fetched;
    while (fetched--) {
      query.context.fetchQuery(query);
    }
  }
};

export class Queries {
  map: Record<string, Query>;
  collectionMap: CollectionMap;

  constructor() {
    // Flattened map of queries by hash. Currently used in contexts
    this.map = {};
    // Nested map of queries by collection then hash
    this.collectionMap = new CollectionMap();
  }

  add(query: Query) {
    this.map[query.hash] = query;
    this.collectionMap.set(query.collectionName, query.hash, query);
  };

  remove(query: Query) {
    delete this.map[query.hash];
    this.collectionMap.del(query.collectionName, query.hash);
  };

  get(contextId, collectionName, expression, options) {
    var hash = queryHash(contextId, collectionName, expression, options);
    return this.map[hash];
  };

  toJSON() {
    var out = [];
    for (var hash in this.map) {
      var query = this.map[hash];
      if (query.subscribeCount || query.fetchCount) {
        out.push(query.serialize());
      }
    }
    return out;
  };
}

export class Query<T = {}> {
  collectionName: string;
  context: Context;
  created: boolean;
  expression: any;
  extraSegments: string[];
  fetchCount: number;
  hash: string;
  idMap: Record<string, any>;
  idsSegments: string[];
  model: Model<ModelData>;
  options: any;
  segments: Segments;
  shareQuery: any | null;
  subscribeCount: number;

  _pendingSubscribeCallbacks: any[];

  constructor(model: ChildModel<unknown>, collectionName: string, expression: any, options?: any) {
    // Note that a new childModel based on the root scope is created. Only the
    // context from the passed in model has an effect
    this.model = model.root.pass({ $query: this });
    this.context = model._context;
    this.collectionName = collectionName;
    this.expression = util.deepCopy(expression);
    this.options = options;
    this.hash = queryHash(this.context.id, collectionName, expression, options);
    this.segments = ['$queries', this.hash];
    this.idsSegments = ['$queries', this.hash, 'ids'];
    this.extraSegments = ['$queries', this.hash, 'extra'];

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
    // Map of id -> count of ids
    this.idMap = {};
  }

  create() {
    this.created = true;
    this.model.root._queries.add(this);
  };

  destroy() {
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

  fetch(cb: ErrorCallback) {
    cb = this.model.wrapCallback(cb);
    this.context.fetchQuery(this);

    this.fetchCount++;

    if (!this.created) this.create();

    var query = this;
    function fetchCb(err: Error, results: any[], extra?: string[]) {
      if (err) return cb(err);
      query._setExtra(extra);
      query._setResults(results);
      cb();   
    }
    this.model.root.connection.createFetchQuery(
      this.collectionName,
      this.expression,
      this.options,
      fetchCb
    );
    return this;
  };

  fetchPromised = promisify(Query.prototype.fetch);

  subscribe(cb: ErrorCallback) {
    cb = this.model.wrapCallback(cb);
    this.context.subscribeQuery(this);

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

    var options = (this.options) ? util.copy(this.options) : {};
    options.results = this._getShareResults();

    // When doing server-side rendering, we actually do a fetch the first time
    // that subscribe is called, but keep track of the state as if subscribe
    // were called for proper initialization in the client
    if (this.model.root.fetchOnly) {
      this._shareFetchedSubscribe(options, cb);
    } else {
      this._shareSubscribe(options, cb);
    }

    return this;
  };

  subscribePromised = promisify(Query.prototype.subscribe);

  _subscribeCb(cb: ErrorCallback) {
    var query = this;
    return function subscribeCb(err: Error, results: ShareDBDoc[], extra?: any) {
      if (err) return query._flushSubscribeCallbacks(err, cb);
      query._setExtra(extra);
      query._setResults(results);
      query._flushSubscribeCallbacks(null, cb);
    };
  };

  _shareFetchedSubscribe(options, cb) {
    this.model.root.connection.createFetchQuery(
      this.collectionName,  
      this.expression,
      options,
      this._subscribeCb(cb),
    );
  };

  _shareSubscribe(options, cb) {
    var query = this;
    // Sanity check, though this shouldn't happen
    if (this.shareQuery) {
      this.shareQuery.destroy();
    }
    this.shareQuery = this.model.root.connection.createSubscribeQuery(
      this.collectionName,
      this.expression,
      options,
      this._subscribeCb(cb),
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
    this.shareQuery.on('extra', function(extra) {
      query.model._setDiffDeep(query.extraSegments, extra);
    });
    this.shareQuery.on('error', function(err) {
      query.model._emitError(err, query.hash);
    });
  };

  _removeMapIds(ids) {
    for (var i = ids.length; i--;) {
      var id = ids[i];
      if (this.idMap[id] > 1) {
        this.idMap[id]--;
      } else {
        delete this.idMap[id];
      }
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
  _addMapIds(ids) {
    for (var i = ids.length; i--;) {
      var id = ids[i];
      this.idMap[id] = (this.idMap[id] || 0) + 1;
    }
  };
  _diffMapIds(ids: string[]) {
    var addedIds = [];
    var removedIds = [];
    var newMap = {};
    for (var i = ids.length; i--;) {
      var id = ids[i];
      newMap[id] = true;
      if (this.idMap[id]) continue;
      addedIds.push(id);
    }
    for (let id in this.idMap) {
      if (newMap[id]) continue;
      removedIds.push(id);
    }
    if (addedIds.length) this._addMapIds(addedIds);
    if (removedIds.length) this._removeMapIds(removedIds);
  };
  _setExtra(extra: string[]) {
    if (extra === undefined) return;
    this.model._setDiffDeep(this.extraSegments, extra);
  };
  _setResults(results: ShareDBDoc[]) {
    var ids = resultsIds(results);
    this._setResultIds(ids);
  };
  _setResultIds(ids: string[]) {
    this._diffMapIds(ids);
    this.model._setArrayDiff(this.idsSegments, ids);
  };
  _maybeUnloadDocs(ids) {
    for (var i = 0; i < ids.length; i++) {
      var id = ids[i];
      this.model._maybeUnloadDoc(this.collectionName, id);
    }
  };

  // Flushes `_pendingSubscribeCallbacks`, calling each callback in the array,
  // with an optional error to pass into each. `_pendingSubscribeCallbacks` will
  // be empty after this runs.
  _flushSubscribeCallbacks(err, cb) {
    cb(err);
    var pendingCallback;
    while ((pendingCallback = this._pendingSubscribeCallbacks.shift())) {
      pendingCallback(err);
    }
  };

  unfetch(cb?: (err?: Error, count?: number) => void) {
    cb = this.model.wrapCallback(cb);
    this.context.unfetchQuery(this);

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

  unfetchPromised = promisify(Query.prototype.unfetch);

  unsubscribe(cb?: (err?: Error, count?: number) => void) {
    cb = this.model.wrapCallback(cb);
    this.context.unsubscribeQuery(this);

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
    function unsubscribeQueryCallback(err?: Error) {
      if (err) return cb(err);
      // Cleanup when no fetches or subscribes remain
      if (!query.fetchCount) query.destroy();
      cb(null, 0);
    }
    return this;
  };

  unsubscribePromised = promisify(Query.prototype.unsubscribe);

  _getShareResults() {
    var ids = this.model._get(this.idsSegments);
    if (!ids) return;

    var collection = this.model.getCollection(this.collectionName);
    if (!collection) return;

    var results = [];
    for (var i = 0; i < ids.length; i++) {
      var id = ids[i];
      var doc = collection.docs[id] as RemoteDoc;
      results.push(doc && doc.shareDoc);
    }
    return results;
  };

  get() {
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
      var doc = (collection && collection.docs[id]) as RemoteDoc;
      results.push(doc && doc.get());
    }
    return results;
  };

  getIds() {
    return this.model._get(this.idsSegments) || [];
  };

  getExtra() {
    return this.model._get(this.extraSegments);
  };

  ref(from) {
    var idsPath = this.idsSegments.join('.');
    return this.model.refList(from, this.collectionName, idsPath);
  };

  refIds(from) {
    var idsPath = this.idsSegments.join('.');
    return this.model.ref(from, idsPath);
  };

  refExtra(from, relPath) {
    var extraPath = this.extraSegments.join('.');
    if (relPath) extraPath += '.' + relPath;
    return this.model.ref(from, extraPath);
  };

  serialize() {
    var ids = this.getIds();
    var collection = this.model.getCollection(this.collectionName);
    var results;
    if (collection) {
      results = [];
      for (var i = 0; i < ids.length; i++) {
        var id = ids[i];
        var doc = collection.docs[id] as RemoteDoc;
        if (doc) {
          delete collection.docs[id];
          var data = doc.shareDoc.data;
          var result = [data, doc.shareDoc.version];
          if (!data || data.id !== id) {
            result[2] = id;
          }
          if (doc.shareDoc.type !== defaultType) {
            result[3] = doc.shareDoc.type && doc.shareDoc.type.name;
          }
          results.push(result);
        } else {
          results.push(id);
        }
      }
    }
    var subscribed = this.context.subscribedQueries[this.hash] || 0;
    var fetched = this.context.fetchedQueries[this.hash] || 0;
    var contextId = this.context.id;
    var counts = (contextId === 'root') ?
      (fetched === 0) ? [subscribed] : [subscribed, fetched] :
      [subscribed, fetched, contextId];
    // TODO: change counts to a less obtuse format. We don't want to change
    // the serialization format unless it is known that clients are not
    // depending on the old format, so this should be done in a major version
    var countsList = [counts];
    var serialized = [
      countsList,
      this.collectionName,
      this.expression,
      results,
      this.options,
      this.getExtra()
    ];
    while (serialized[serialized.length - 1] == null) {
      serialized.pop();
    }
    return serialized;
  };
}
function queryHash(contextId, collectionName, expression, options) {
  var args = [contextId, collectionName, expression, options];
  return JSON.stringify(args).replace(/\./g, '|');
}

function resultsIds(results: { id: string }[]): string[] {
  var ids = [];
  for (var i = 0; i < results.length; i++) {
    var shareDoc = results[i];
    ids.push(shareDoc.id);
  }
  return ids;
}
