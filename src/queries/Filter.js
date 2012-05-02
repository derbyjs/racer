var lookup = require('../path').lookup
  , transaction = require('../transaction')
  , util = require('../util')
  , indexOf = util.indexOf
  , deepIndexOf = util.deepIndexOf
  , deepEqual = util.deepEqual;

module.exports = Filter;

// params look like:
// {
//   from: 'collectionName'
// , byKey: keyVal
// , equals: {
//     somePath: someVal
// , }
// , notEquals: {
//     somePath: someVal
//   }
// , sort: ['fieldA', 'asc', 'fieldB', 'desc']
// }
function Filter (params) {
  // Stores a list of predicate functions that take a document and return a
  // Boolean. If all predicate functions return true, then the document passes
  // through the filter. If not, the document is blocked by the filter
  this._predicates = [];

  if (params) for (var method in params) {
    this[method].call(this, params[method]);
  }
}

Filter.prototype.from = function from (ns) {
  this._predicates.push( function (doc, channel) {
    var docNs = channel.slice(0, channel.indexOf('.'));
    return ns === docNs;
  });
  return this;
};

Filter.prototype.byKey = function byKey (keyVal) {
  this._predicates.push( function (doc, channel) {
    var id = channel.split('.')[1];
    return id === keyVal
  });
  return this;
};

Filter.prototype._addAsPredicates = function _addAsPredicates (params, fn) {
  var predicates = this._predicates;
  for (var fieldName in params) {
    predicates.push( fn.bind(undefined, fieldName, params[fieldName]) );
  }
};

var predicateBuilders = {
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
      if (x.constructor === Object) return ~deepIndexOf(list, x);
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
};

for (var method in predicateBuilders) {
  Filter.prototype[method] = (function (predicateBuilder) {
    return function (params) {
      this._addAsPredicates(params, predicateBuilder);
      return this;
    };
  })(predicateBuilders[method]);
}

Filter.prototype.test = function test (doc, channel) {
  // Lazy compile the aggregate doc predicate
  this.test = compileDocFilter(this._predicates);
  return this.test(doc, channel);
}

function compileDocFilter (predicates) {
  switch (predicates.length) {
    case 0: return evalToTrue;
    case 1: return predicates[0];
  }
  return function test (doc, channel) {
    if (typeof doc === 'undefined') return false;
    for (var i = 0, l = predicates.length; i < l; i++) {
      if (! predicates[i](doc, channel)) return false;
    }
    return true;
  };
}

function evalToTrue () { return true; }
