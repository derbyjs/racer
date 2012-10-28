// TODO JSDoc
var filterUtils = require('../../computed/filter')
  , filterFnFromQuery = filterUtils.filterFnFromQuery
  , filterDomain = filterUtils.filterDomain
  , sortUtils = require('../../computed/sort')
  , deriveComparator = sortUtils.deriveComparator
  , util = require('../../util')
  , Promise = util.Promise
  , merge = util.merge
  , objectExcept = require('../../path').objectExcept
  ;

module.exports = MemoryQuery;

/**
 * MemoryQuery instances are used:
 * - On the server when DbMemory database adapter is used
 * - On QueryNodes stored inside a QueryHub to figure out which transactions
 *   trigger query result changes to publish to listeners.
 * - Inside the browser for filters
 *
 * @param {Object} json representing a query that is typically created via
 * convenient QueryBuilder instances. See QueryBuilder.js for more details.
 */
function MemoryQuery (json, filterFn) {
  this.ns = json.from;
  this._json = json;
  var filteredJson = objectExcept(json, ['only', 'except', 'limit', 'skip', 'sort', 'type']);
  this._filter = filterFn || filterFnFromQuery(filteredJson);
  for (var k in json) {
    if (k === 'type') {
      // json[k] can be: 'find', 'findOne', 'count', etc.
      this[json[k]]();
    } else if (k in this) {
      this[k](json[k]);
    }
  }
}

MemoryQuery.prototype.toJSON = function toJSON () {
  return this._json;
};

/**
 * Specify that documents in the result set are stripped of all fields except
 * the ones specified in `paths`
 * @param {Object} paths to include. The Object maps String -> 1
 * @return {MemoryQuery} this for chaining
 * @api public
 */
MemoryQuery.prototype.only = function only (paths) {
  if (this._except) {
    throw new Error("You can't specify both query(...).except(...) and query(...).only(...)");
  }
  var only = this._only || (this._only = {id: 1});
  merge(only, paths);
  return this;
};

/**
 * Specify that documents in the result set are stripped of the fields
 * specified in `paths`. You aren't allowed to exclude the path "id"
 * @param {Object} paths to exclude. The Object maps String -> 1
 * @return {MemoryQuery} this for chaining
 * @api public
 */
MemoryQuery.prototype.except = function except (paths) {
  if (this._only) {
    throw new Error("You can't specify both query(...).except(...) and query(...).only(...)");
  }
  var except = this._except || (this._except = {});
  if ('id' in paths) {
    throw new Error('You cannot ignore `id`');
  }
  merge(except, paths);
  return this;
};

// Specify that the result set includes no more than `lim` results
// @param {Number} lim is the number of results to which to limit the result set
MemoryQuery.prototype.limit = function limit (lim) {
  this.isPaginated = true;
  this._limit = lim;
  return this;
};

// Specify that the result set should skip the first `howMany` results out of
// the entire set of results that match the equivlent query without a skip or
// limit.
MemoryQuery.prototype.skip = function skip (howMany) {
  this.isPaginated = true;
  this._skip = howMany;
  return this;
};

// e.g.,
// sort(['field1', 'asc', 'field2', 'desc', ...])
/**
 * mquery.sort(['field1', 'asc', 'field2', 'desc']);
 *
 * OR
 *
 * mquery.sort( function (x, y) {
 *   if (x > y) return 1;
 *   if (x < y) return -1;
 *   return 0;
 * });
 *
 * @param {Array|Function} params
 * @return {MemoryQuery}
 */
MemoryQuery.prototype.sort = function (params) {
  if (typeof params === 'function') {
    this._comparator = params;
    return this;
  }
  var sort = this._sort;
  if (sort && sort.length) {
    sort = this._sort = this._sort.concat(params);
  } else {
    sort = this._sort = params;
  }
  this._comparator = deriveComparator(sort);
  return this;
};


MemoryQuery.prototype.filterTest = function filterTest (doc, ns) {
  if (ns !== this._json.from) return false;
  return this._filter(doc);
};

MemoryQuery.prototype.run = function (memoryAdapter, cb) {
  var promise = (new Promise).on(cb)
    , searchSpace = memoryAdapter._get(this._json.from)
    , matches = this.syncRun(searchSpace);

  promise.resolve(null, matches);

  return promise;
};

MemoryQuery.prototype.syncRun = function (searchSpace) {
  var matches = filterDomain(searchSpace, this._filter, this._json.from);
  return this.getType(this.type).exec(matches, this);
};

var queryTypes = require('./types')
  , registerType = require('./types/register');
for (var t in queryTypes) {
  registerType(MemoryQuery, t, queryTypes[t]);
}
