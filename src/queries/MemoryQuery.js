var createFilter = require('./filter')
  , util = require('../util')
  , Promise = util.Promise
  , merge = util.merge
  , path = require('../path')
  , lookup = path.lookup
  , objectWithOnly = path.objectWithOnly
  , objectExcept = path.objectExcept
  ;

module.exports = MemoryQuery;

// MemoryQuery instances are used:
// - On the server when DbMemory database adapter is used
// - On QueryNodes stored inside a QueryHub to figure out which transactions
//   trigger query result changes to publish to listeners.
// - Inside the browser for in-browser queries
// @param {Object} json representing a query that is typically created via
// convenient QueryBuilder instances. See QueryBuilder.js for more details.
function MemoryQuery (json) {
  this._json = json;
  var filteredJson = objectExcept(json, ['only', 'except', 'limit', 'skip', 'sort', 'type']);
  this._filter = createFilter(filteredJson);
  for (var k in json) {
    if (k === 'type') {
      // find() or findOne()
      this[json[k]]();
    } else if (k in this) {
      this[k](json[k]);
    }
  }
}

MemoryQuery.prototype.toJSON = function toJSON () { return this._json; };

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
function compileSortComparator (__sortParams__) {
  return function comparator (a, b, sortParams) {
    sortParams || (sortParams = __sortParams__);
    var dir, path, factor, aVal, bVal
      , aIsIncomparable, bIsIncomparable;
    for (var i = 0, l = sortParams.length; i < l; i+=2) {
      var dir = sortParams[i+1];
      switch (dir) {
        case 'asc' : factor =  1; break;
        case 'desc': factor = -1; break;
        default: throw new Error('Must be "asc" or "desc"');
      }
      path = sortParams[i];
      aVal = lookup(path, a);
      bVal = lookup(path, b);

      // Handle undefined, null, or in-comparable aVal and/or bVal.
      aIsIncomparable = isIncomparable(aVal)
      bIsIncomparable = isIncomparable(bVal);

      // Incomparables always come last.
      if ( aIsIncomparable && !bIsIncomparable) return factor;
      // Incomparables always come last, even in reverse order.
      if (!aIsIncomparable &&  bIsIncomparable) return -factor;

      // Tie-break 2 incomparable fields by comparing more downstream ones
      if ( aIsIncomparable &&  bIsIncomparable) continue;

      // Handle comparable field values
      if      (aVal < bVal) return -factor;
      else if (aVal > bVal) return factor;

      // Otherwise, the field values for both docs so far are equivalent
    }
    return 0;
  };
}

function isIncomparable (x) {
  return (typeof x === 'undefined') || x === null;
}

MemoryQuery.prototype.find = function find () {
  this._type = 'find';
  this._json.type = 'find';
  return this;
};

MemoryQuery.prototype.findOne = function findOne () {
  this._type = 'findOne';
  this._json.type = 'findOne';
  return this;
};

MemoryQuery.prototype.filterTest = function filterTest (doc, ns) {
  return this._filter(doc, ns);
};

MemoryQuery.prototype.run = function run (memoryAdapter, cb) {
  var promise = (new Promise).on(cb)
    , searchSpace = memoryAdapter._get(this._json.from)
    , matches = this.syncRun(searchSpace);

  promise.resolve(null, matches);

  return promise;
};

MemoryQuery.prototype.syncRun = function syncRun (searchSpace) {
  var filter = this._filter
    , matches = filterWorld(searchSpace, filter, this._json.from)
    , comparator = this._comparator;
  if (comparator) matches = matches.sort(comparator);

  // Handle skip/limit for pagination
  var skip = this._skip
    , limit = this._limit
    , only = this._only
    , except = this._except;

  if (typeof limit !== 'undefined') {
    if (typeof skip === 'undefined') skip = 0;
    matches = matches.slice(skip, skip + limit);
  }

  if (this._type === 'findOne') {
    // Do this to limit the work of the next field filtering step
    matches = [matches[0]];
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
  if (this._type === 'findOne') return matches[0];
  return matches;
}

function filterObject (obj, filterFn, extra, start) {
  var filtered = start || {}
    , outputAsArray = Array.isArray(filtered);
  if (Array.isArray(obj)) {
    for (var i = 0, l = obj.length; i < l; i++) {
      if (filterFn(obj[i], extra)) {
        filtered[filtered.length] = obj[i];
      }
    }
  } else {
    var i = 0
    for (var k in obj) {
      if (filterFn(obj[k], extra)) {
        filtered[outputAsArray ? i++ : k] = obj[k];
      }
    }
  }
  return filtered;
};

function filterWorld (docs, filterFn, ns) {
  if (ns) {
    return filterObject(docs, filterFn, ns, []);
  }
  var results = {};
  for (ns in docs) {
    docs = docs[ns];
    var newResults = filterObject(docs, filterFn, ns, []);
    results = results.concat(newResults);
  }
  return results;
}
