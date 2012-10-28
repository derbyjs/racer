// TODO Update queryTuple comments to reflect current structure

var deepEqual = require('../../util').deepEqual
  , objectExcept = require('../../path').objectExcept
  , MemoryQuery = require('./MemoryQuery')
  , QueryBuilder = require('./QueryBuilder')
  ;

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
  // The `query` property is lazily created via QueryRegistry#memoryQuery
  this._queries = {};

  this._ordered = [];

  // Maps ns -> [queryIds...]
  this._queryIdsByNs = {};

  // Maps tag -> [queryIds...]
  // This is used for quick lookup of queries by tag
  this._queryIdsByTag = {};

  this._nextId = 1;
  var self = this;
  this._nextQueryId = function () {
    return '_' + (self._nextId++);
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
    maxQueryId = Math.max(maxQueryId, parseInt(queryId.slice(1 /* rm '_'*/), 10));
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

, bundle: function () {
    var ordered = this._ordered
      , queries = this._queries
      , bundle = [];
    for (var i = 0, l = ordered.length; i < l; i++) {
      var pair = ordered[i]
        , queryId = pair[0]
        , tag = pair[1]
        ;
      bundle.push([queries[queryId].tuple, tag]);
    }
    return bundle;
  }

  /**
   * Adds a query to the registry.
   *
   * @param {Array} queryTuple is [ns, [queryMotif, queryArgs...], ...]
   * @return {String|null} the query id if add succeeds. null if add fails.
   * @api public
   */
, add: function (queryTuple, queryMotifRegistry, force) {
    var queryId = this.queryId(queryTuple);

    // NOTE It's important for some query types to send the queryId to the
    // Store, so the Store can use it. For example, the `count` query needs to
    // send over the queryId, so that the Store can send back the proper data
    // instructions that includes a path at which to store the count result.
    // TODO In the future, we can figure out the path based on a more generic
    // means to load data into our Model from the Store. So we can remove this
    // line later
    if (!queryTuple[3]) queryTuple[3] = queryId;

    if (!force && queryId) return null;

    if (!queryTuple[2]) queryTuple[2] = null;

    var queries = this._queries;
    if (! (queryId in queries)) {
      if (queryTuple[2] === 'count') { // TODO Use types/ somehow
        var queryJson = queryMotifRegistry.queryJSON(queryTuple);
        queryId = QueryBuilder.hash(queryJson);
      } else {
        queryId = this._nextQueryId();
      }
      queryTuple[3] = queryId;

      queries[queryId] = {
        id: queryId
      , tuple: queryTuple
      , tags: []
      };

      var ns = queryTuple[0]
        , queryIdsByNs = this._queryIdsByNs
        , queryIds = queryIdsByNs[ns] || (queryIdsByNs[ns] = []);
      if (queryIds.indexOf(queryId) === -1) {
        queryIds.push(queryId);
      }
    }

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
   * @param {Array} queryTuple of the form
   * [ns, {motifA: argsA, motifB: argsB, ...}, queryId]
   * @return {Object} returns registered info about the query
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
    // queryTuple has the form:
    // [ns, argsByMotif, typeMethod, queryId]
    // where
    // argsByMotif: maps query motif names to motif arguments
    // typeMethod: e.g., 'one', 'count'
    // queryId: is an id (specific to the clientId) assigned by the
    // QueryRegistry to the query
    if (queryTuple.length === 4) {
      return queryTuple[3];
    }

    var ns = queryTuple[0]
      , queryIds = this._queryIdsByNs[ns]
      , queries = this._queries;
    if (!queryIds) return null;
    var motifs = queryTuple[1]
      , typeMethod = queryTuple[2];
    for (var i = queryIds.length; i--; ) {
      var queryId = queryIds[i]
        , tuple = queries[queryId].tuple
        , currMotifs = tuple[1]
        , currTypeMethod = tuple[2]
        ;
      if (deepEqual(currMotifs, motifs) && currTypeMethod == typeMethod) {
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
    var meta = this.lookup(queryTuple)
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
      this._ordered.push([queryId, tag]);
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
      , found = []
      , query;
    if (queryIds) {
      for (var i = 0, l = queryIds.length; i < l; i++) {
        query = queries[queryIds[i]];
        if (query) found.push(query.tuple);
      }
    }
    return found;
  }
};
