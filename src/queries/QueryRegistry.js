// TODO Update queryTuple comments to include queryId as queryTuple[0]

var deepEqual = require('../util').deepEqual
  , objectExcept = require('../path').objectExcept
  , MemoryQuery = require('./MemoryQuery');

module.exports = QueryRegistry;

/**
 * QueryRegistry is used by Model to keep track of queries and their metadata.
 */
function QueryRegistry () {
  // Maps queryId ->
  //        id: queryId
  //        tuple: [ns, {<queryMotif>: queryArgs, ...}, queryId]
  //        query: <# MemoryQuery>
  //        tags: [tags...]
  //
  // Note that the `query` property is lazily created via QueryRegistry#memoryQuery
  this._queries = {};

  // Maps ns -> [queryIds...]
  this._queryIdsByNs = {};

  // Maps tag -> [queryIds...]
  // This is used for quick lookup of queries by tag
  this._queryIdsByTag = {};

  this._nextId = 1;
  var self = this;
  this._nextQueryId = function () {
    return (self._nextId++).toString();
  }
}

/**
 * Creates a QueryRegistry instance from json that has been generated from
 * QueryBuilder#toJSON
 *
 * @param {Object} json
 * @param {Object} queryMotifRegistry contains all registered query motifs
 * @return {QueryRegistry}
 * @api public
 */
QueryRegistry.fromJSON = function (json, queryMotifRegistry) {
  var registry = new QueryRegistry
    , queryIdsByNs = registry._queryIdsByNs
    , queryIdsByTag = registry._queryIdsByTag
    , maxQueryId = 0;

  registry._queries = json;

  for (var queryId in json) {
    var curr = json[queryId]
      , queryTuple = curr.tuple
      , ns = queryTuple[0];

    // Re-construct queryIdsByNs index
    var queryIds = queryIdsByNs[ns] || (queryIdsByNs[ns] = []);
    queryIds.push(queryId);

    // Re-construct queryIdsByTag index
    var tags = curr.tags;
    for (var i = tags.length; i--; ) {
      var tag = tags[i]
        , taggedQueryIds = queryIdsByTag[tag] ||
                          (queryIdsByTag[tag] = []);
      if (-1 === taggedQueryIds.indexOf(queryId)) {
        taggedQueryIds.push(queryId);
      }
    }

    // Keep track of a max queryId, so we can assign the _nextQueryId upon the
    // next call to QueryRegistry#add
    maxQueryId = Math.max(maxQueryId, parseInt(queryId, 10));
  }
  registry._nextId = ++maxQueryId;
  return registry;
};

QueryRegistry.prototype = {
  toJSON: function () {
    var queries = this._queries
      , json = {};
    for (var queryId in queries) {
      // Ignore the MemoryQuery instance
      json[queryId] = objectExcept(queries[queryId], 'query');
    }
    return json;
  }

  /**
   * Adds a query to the registry.
   *
   * @param {Array} queryTuple is [ns, [queryMotif, queryArgs...], ...]
   * @return {String|null} the query id if add succeeds. null if add fails.
   * @api public
   */
, add: function (queryTuple) {
    var queryId = this.queryId(queryTuple);
    if (queryId) return null;

    queryId = queryTuple[queryTuple.length] = this._nextQueryId();

    this._queries[queryId] = {
      id: queryId
    , tuple: queryTuple
    , tags: []
    };

    var ns = queryTuple[0]
      , queryIdsByNs = this._queryIdsByNs
      , queryIds = queryIdsByNs[ns] || (queryIdsByNs[ns] = []);
    queryIds.push(queryId);

    return queryId;
  }

  /**
   * Removes a query from the registry.
   *
   * @param {Array} queryTuple
   * @return {Boolean} true if remove succeeds. false if remove fails.
   * @api public
   */
, remove: function (queryTuple) {
    // TODO Return proper Boolean value
    var queries = this._queries
      , queryId = this.queryId(queryTuple)
      , meta = queries[queryId];

    // Clean up tags
    var tags = meta.tags
      , queryIdsByTag = this._queryIdsByTag;
    for (var i = tags.length; i--; ) {
      var tag = tags[i]
        , queryIds = queryIdsByTag[tag];
      queryIds.splice(queryIds.indexOf(queryId), 1);
      if (! queryIds.length) delete queryIdsByTag[tag];
    }

    // Clean up queryIdsByNs index
    var ns = queryTuple[0]
      , queryIdsByNs = this._queryIdsByNs
      , queryIds = queryIdsByNs[ns]
      , queryId = queryTuple[queryTuple.length - 1];
    queryIds.splice(queryIds.indexOf(queryId));
    if (! queryIds.length) delete queryIdsByNs[ns];

    // Clean up queries
    delete queries[queryId];
  }

  /**
   * Looks up a query in the registry.
   *
   * @param {Array} queryTuple of the form [queryMotif, queryArgs...]
   * @api public
   */
, lookup: function (queryTuple) {
    var queryId = this.queryId(queryTuple);
    return this._queries[queryId];
  }

  /**
   * Returns the queryId of the queryTuple
   *
   * @param {Array} queryTuple
   */
, queryId: function (queryTuple) {
    var last = queryTuple[queryTuple.length - 1];
    if (typeof last === 'string') return last;

    var ns = queryTuple[0]
      , queryIds = this._queryIdsByNs[ns]
      , queries = this._queries;
    if (!queryIds) return null;
    for (var i = queryIds.length; i--; ) {
      var queryId = queryIds[i]
        , tuple = queries[queryId].tuple;
      // Rm the queryId at the end
      tuple = tuple.slice(0, tuple.length-1);
      if (deepEqual(tuple, queryTuple)) {
        return queryId;
      }
    }
    return null;
  }

  /**
   * @param {Array} queryTuple
   * @param {QueryMotifRegistry} queryMotifRegistry
   * @return {MemoryQuery}
   * @api public
   */
, memoryQuery: function (queryTuple, queryMotifRegistry) {
    var meta = this.lookup(queryTuple) || {}
      , memoryQuery = meta.query;
    if (memoryQuery) return memoryQuery;

    var queryJson = queryMotifRegistry.queryJSON(queryTuple);
    if (! queryJson.type) queryJson.type = 'find';
    return meta.query = new MemoryQuery(queryJson);
  }

  /**
   * Tags a query registered in the registry as queryId. The QueryRegistry can
   * then look up query tuples by tag via Query#lookupWithTag.
   *
   * @param {String} queryId
   * @param {String} tag
   * @return {Boolean}
   * @api public
   */
, tag: function (queryId, tag) {
    var queryIdsByTag = this._queryIdsByTag
      , queryIds = queryIdsByTag[tag] ||
                  (queryIdsByTag[tag] = []);
    if (-1 === queryIds.indexOf(queryId)) {
      queryIds.push(queryId);
      return true;
    }
    return false;
  }

  /**
   * Untags a query registered in the registry as queryId. This will change
   * the query tuple results returned by Query#lookupWithTag.
   *
   * @param {String} queryId
   * @param {String} tag
   * @return {Boolean}
   * @api public
   */
, untag: function (queryId, tag) {
    var queryIdsByTag = this._queryIdsByTag;
    if (! (tag in queryIdsByTag)) return false;
    var queryIds = queryIdsByTag[tag]
      , pos = queryIds.indexOf(queryId);
    if (pos === -1) return false;
    queryIds.splice(pos, 1);
    if (! queryIds.length) delete queryIdsByTag[tag];
    return true;
  }

  /**
   * Returns all registered query tuples that have been tagged with the given
   * tag.
   *
   * @param {String} tag
   * @return {Array} array of query tuples
   * @api public
   */
, lookupWithTag: function (tag) {
    var queryIdsByTag = this._queryIdsByTag
      , queryIds = queryIdsByTag[tag]
      , queries = this._queries
      , found = [];
    if (queryIds) {
      for (var i = 0, l = queryIds.length; i < l; i++) {
        var currId = queryIds[i];
        found.push(queries[currId].tuple);
      }
    }
    return found;
  }
};
