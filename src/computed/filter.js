var lookup = require('../path').lookup
  , transaction = require('../transaction')
  , util = require('../util')
  , indexOf = util.indexOf
  , deepIndexOf = util.deepIndexOf
  , deepEqual = util.deepEqual
  , QueryBuilder = require('../descriptor/query/QueryBuilder')
  , specIdentifier = require('../util/speculative').identifier

module.exports = {
  filterFnFromQuery: filterFnFromQuery
, filterDomain: filterDomain
, deriveFilterFn: deriveFilterFn
};

/**
 * Creates a filter function based on a query represented as json.
 *
 * @param {Object} json representing a query that is typically created via
 * convenient QueryBuilder instances
 *
 * json looks like:
 * {
 *    from: 'collectionName'
 *  , byId: id
 *  , equals: {
 *      somePath: someVal
 *  , }
 *  , notEquals: {
 *      somePath: someVal
 *    }
 *  , sort: ['fieldA', 'asc', 'fieldB', 'desc']
 *  }
 *
 * @return {Function} a filter function
 * @api public
 */
function filterFnFromQuery (json) {
  // Stores a list of predicate functions that take a document and return a
  // Boolean. If all predicate functions return true, then the document passes
  // through the filter. If not, the document is blocked by the filter
  var predicates = []
    , pred;

  if (json) for (var method in json) {
    if (method === 'from') continue;
    pred = predicateBuilders[method](json[method]);
    if (Array.isArray(pred)) predicates = predicates.concat(pred);
    else predicates.push(pred);
  }

  return compileDocFilter(predicates);
}

var predicateBuilders = {};

predicateBuilders.byId = function byId (id) {
  return function (doc) { return doc.id === id; };
};

var fieldPredicates = {
    equals: function (fieldName, val, doc) {
      var currVal = lookup(fieldName, doc);
      if (typeof currVal === 'object') {
        return deepEqual(currVal, val);
      }
      return currVal === val;
    }
  , notEquals: function (fieldName, val, doc) {
      var currVal = lookup(fieldName, doc);
      if (typeof currVal === 'object') {
        return ! deepEqual(currVal, val);
      }
      return currVal !== val;
    }
  , gt: function (fieldName, val, doc) {
      return lookup(fieldName, doc) > val;
    }
  , gte: function (fieldName, val, doc) {
      return lookup(fieldName, doc) >= val;
    }
  , lt: function (fieldName, val, doc) {
      return lookup(fieldName, doc) < val;
    }
  , lte: function (fieldName, val, doc) {
      return lookup(fieldName, doc) <= val;
    }
  , within: function (fieldName, list, doc) {
      if (!list.length) return false;
      var x = lookup(fieldName, doc);
      if (x && x.constructor === Object) return ~deepIndexOf(list, x);
      return ~list.indexOf(x);
    }
  , contains: function (fieldName, list, doc) {
      var docList = lookup(fieldName, doc);
      if (typeof docList === 'undefined') {
        if (list.length) return false;
        return true; // contains nothing
      }
      for (var x, i = list.length; i--; ) {
        x = list[i];
        if (x.constructor === Object) {
          if (-1 === deepIndexOf(docList, x)) return false;
        } else {
          if (-1 === docList.indexOf(x)) return false;
        }
      }
      return true;
    }
  , exists: function (fieldName, shouldExist, doc) {
      var val = lookup(fieldName, doc)
        , doesExist = (typeof val !== 'undefined');
      return doesExist === shouldExist;
    }
};

for (var queryKey in fieldPredicates) {
  predicateBuilders[queryKey] = (function (fieldPred) {
    return function (params) {
      return createDocPredicates(params, fieldPred);
    };
  })(fieldPredicates[queryKey]);
}

function createDocPredicates (params, fieldPredicate) {
  var predicates = []
    , docPred;
  for (var fieldName in params) {
    docPred = fieldPredicate.bind(undefined, fieldName, params[fieldName]);
    predicates.push(docPred);
  }
  return predicates;
};

function compileDocFilter (predicates) {
  switch (predicates.length) {
    case 0: return evalToTrue;
    case 1: return predicates[0];
  }
  return function test (doc) {
    if (typeof doc === 'undefined') return false;
    for (var i = 0, l = predicates.length; i < l; i++) {
      if (! predicates[i](doc)) return false;
    }
    return true;
  };
}

/**
 * @api private
 */
function evalToTrue () { return true; }

/**
 * Returns the set of docs from searchSpace that pass filterFn.
 *
 * @param {Object|Array} searchSpace
 * @param {Function} filterFn
 * @param {String} ns
 * @return {Object|Array} the filtered values
 * @api public
 */
function filterDomain (searchSpace, filterFn) {
  if (Array.isArray(searchSpace)) {
    return searchSpace.filter(filterFn);
  }

  var filtered = {};
  for (var k in searchSpace) {
    if (k === specIdentifier) continue;
    var curr = searchSpace[k];
    if (filterFn(curr)) {
      filtered[k] = curr;
    }
  }
  return filtered;
}

/**
 * Derives the filter function, based on filterSpec and source.
 *
 * @param {Function|Object} filterSpec is a representation of the filter
 * @param {String} source is the path to the data that we want to filter
 * @param {Boolean} single specifies whether to filter down to a single
 * resulting Object.
 * @return {Function} filter function
 * @api private
 */
function deriveFilterFn (filterSpec, source, single) {
  if (typeof filterSpec === 'function') {
    var numArgs = filterSpec.length;
    if (numArgs === 1) return filterSpec;
    if (numArgs === 0) {
      var queryBuilder = new QueryBuilder({from: source});
      queryBuilder = filterSpec.call(queryBuilder);
      if (single) queryBuilder.on();
      var queryJson = queryBuilder.toJSON();
      var filter = filterFnFromQuery(queryJson);
      if (queryJson.sort) {
        // TODO
      }
    }
    throw new Error('filter spec must be either a function with 0 or 1 argument, or an Object');
  }
  // Otherwise, filterSpec is an Object representing query params
  filterSpec.from = source;
  var queryBuilder = new QueryBuilder(filterSpec);
  if (single) queryBuilder.one();
  return filterFnFromQuery(queryBuilder.toJSON());
}
