var Filter = require('./Filter')
  , util = require('../util')
  , Promise = util.Promise
  , merge = util.merge
  , path = require('../path')
  , lookup = path.lookup
  , objectWithOnly = path.objectWithOnly
  , objectExcept = path.objectExcept
  ;

module.exports = MemoryQuery;

// @param {Object} json representing a query that is typically created via
// convenient QueryBuilder instances. See QueryBuilder.js for more details.
function MemoryQuery (json) {
  var filteredJson = objectExcept(json, ['only', 'except', 'limit', 'skip', 'sort']);
  this._filter = new Filter(filteredJson);
  for (var k in json) {
    if (k in this) {
      this[k](json[k]);
    }
  }
}

// Specify that documents in the result set are stripped of all fields except
// the ones specified in `paths`
// @param {Object} paths to include. The Object maps String -> 1
MemoryQuery.prototype.only = function only (paths) {
  if (this._except) {
    throw new Error("You can't specify both query(...).except(...) and query(...).only(...)");
  }
  var only = this._only || (this._only = {id: 1});
  merge(only, paths);
  return this;
};

// Specify that documents in the result set are stripped of the fields
// specified in `paths`. You aren't allowed to exclude the path "id"
// @param {Object} paths to exclude. The Object maps String -> 1
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
  this._comparator = compileSortComparator(sort);
  return this;
};

// Generates a comparator function that returns -1, 0, or 1
// if a < b, a == b, or a > b respectively, according to the ordering criteria
// defined by sortParams
// , e.g., sortParams = ['field1', 'asc', 'field2', 'desc']
function compileSortComparator (sortParams) {
  return function (a, b) {
    var factor, path, aVal, bVal;
    for (var i = 0, l = sortParams.length; i < l; i+=2) {
      switch (sortParams[i+1]) {
        case 'asc' : factor =  1; break;
        case 'desc': factor = -1; break;
        default: throw new Error('Must be "asc" or "desc"');
      }
      path = sortParams[i];
      aVal = lookup(path, a);
      bVal = lookup(path, b);
      // TODO Handle undefined aVal or bVal
      if      (aVal < bVal) return -factor;
      else if (aVal > bVal) return factor;
    }
    return 0;
  };
}

// TODO find and findOne

MemoryQuery.prototype.run = function run (memoryAdapter, cb) {
  var promise = (new Promise).on(cb)
    , filter = this._filter
    , matches = memoryAdapter.filter( function (doc, nsPlusId) {
        return filter.test(doc, nsPlusId);
      });

  var comparator = this._comparator;
  if (comparator) matches.sort(comparator);

  // Handle skip/limit for pagination
  var skip = this._skip
    , limit = this._limit
    , only = this._only
    , except = this._except;

  if (typeof limit !== 'undefined') {
    if (typeof skip === 'undefined') skip = 0;
    matches = matches.slice(skip, skip + limit);
  }

  // Finally, selectively return the documents with a subset of fields based on
  // `except` or `only`
  var projectObject, fields;
  if (only) {
    projectObject = objectWithOnly;
    fields = Object.keys(only);
  } else if (except) {
    projectObject = objectExcept;
    fields = Object.keys(except);
  }
  if (projectObject) {
    matches = matches.map( function (doc) {
      return projectObject(doc, fields);
    });
  }

  promise.resolve(null, matches);

  return promise;
};
