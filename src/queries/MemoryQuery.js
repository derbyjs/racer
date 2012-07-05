// TODO JSDoc
var filterUtils = require('../computed/filter')
  , filterFnFromQuery = filterUtils.filterFnFromQuery
  , filterDomain = filterUtils.filterDomain
  , sliceDomain = require('../computed/range').sliceDomain
  , sortUtils = require('../computed/sort')
  , sortDomain = sortUtils.sortDomain
  , deriveComparator = sortUtils.deriveComparator
  , projectDomain = require('../computed/project').projectDomain
  , util = require('../util')
  , Promise = util.Promise
  , merge = util.merge
  , objectExcept = require('../path').objectExcept
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
      // find() or findOne()
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
MemoryQuery.prototype.sort = function sort (params) {
  var sort = this._sort;
  if (sort && sort.length) {
    sort = this._sort = this._sort.concat(params);
  } else {
    sort = this._sort = params;
  }
  this._comparator = deriveComparator(sort);
  return this;
};

MemoryQuery.prototype.find = function find () {
  this.type = 'find';
  this._json.type = 'find';
  return this;
};

MemoryQuery.prototype.findOne = function findOne () {
  this.type = 'findOne';
  this._json.type = 'findOne';
  return this;
};

MemoryQuery.prototype.filterTest = function filterTest (doc, ns) {
  if (ns !== this._json.from) return false;
  return this._filter(doc);
};

MemoryQuery.prototype.run = function run (memoryAdapter, cb) {
  var promise = (new Promise).on(cb)
    , searchSpace = memoryAdapter._get(this._json.from)
    , matches = this.syncRun(searchSpace);

  promise.resolve(null, matches);

  return promise;
};

MemoryQuery.prototype.syncRun = function syncRun (searchSpace) {
  var matches = filterDomain(searchSpace, this._filter, this._json.from);

  // Query results should always be a list. sort co-erces the results into a
  // list even if comparator is not present.
  matches = sortDomain(matches, this._comparator);

  // Handle skip/limit for pagination
  var skip = this._skip
    , limit = this._limit;
  if (typeof limit !== 'undefined') {
    matches = sliceDomain(matches, skip, limit);
  }

  // Truncate to limit the work of the next field filtering step
  if (this.type === 'findOne') {
    matches = [matches[0]];
  }

  // Selectively return the documents with a subset of fields based on
  // `except` or `only`
  var only = this._only
    , except = this._except;
  if (only || except) {
    matches = projectDomain(matches, only || except, !!except);
  }

  if (this.type === 'findOne') return matches[0];
  return matches;
}
