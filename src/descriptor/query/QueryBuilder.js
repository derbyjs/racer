module.exports = QueryBuilder;

var reserved = {
    equals: 1
  , notEquals: 1
  , gt: 1
  , gte: 1
  , lt: 1
  , lte: 1
  , within: 1
  , contains: 1
  , exists: 1
};

var validQueryParams = {
    from: 1
  , byId: 1
  , where: 1
  , skip: 1
  , limit: 1
  , sort: 1
  , except: 1
  , only: 1
};

// QueryBuilder constructor
// @param {Object} params looks like:
//   {
//     from: 'someNamespace'
//   , where: {
//       name: 'Gnarls'
//     , gender: { notEquals: 'female' }
//     , age: { gt: 21, lte: 30 }
//     , tags: { contains: ['super', 'derby'] }
//     , shoe: { within: ['nike', 'adidas'] }
//     }
//   , sort: ['fieldA', 'asc', 'fieldB', 'desc']
//   , skip: 10
//   , limit: 5
//   }
function QueryBuilder (params) {
  this._json = {};

  if (params) this.query(params);
}

function keyMatch (obj, fn) {
  for (var k in obj) {
    if (fn(k)) return true;
  }
  return false;
}

function isReserved (key) { return key in reserved; }

var proto = QueryBuilder.prototype = {
    from: function (from) {
      this.ns = from;
      this._json.from = from;
      return this;
    }
  , byId: function (id) {
      this._json.byId = id;
      return this;
    }
  , where: function (param) {
      if (typeof param === 'string') {
        this._currField = param;
        return this;
      }

      if (param.constructor !== Object) {
        console.error(param);
        throw new Error("Invalid `where` param");
      }

      for (var fieldName in param) {
        this._currField = fieldName;
        var arg = param[fieldName]
        if (arg.constructor !== Object) {
          this.equals(arg);
        } else if (keyMatch(arg, isReserved)) {
          for (var comparator in arg) {
            this[comparator](arg[comparator]);
          }
        } else {
          this.equals(arg);
        }
      }
    }
  , toJSON: function () {
      var json = this._json;
      if (this.type && !json.type) json.type = this.type;
      return json;
    }

    /**
     * Entry-point for more coffee-script style query building.
     *
     * @param {Object} params representing additional query method calls
     * @return {QueryBuilder} this for chaining
     */
  , query: function (params) {
      for (var k in params) {
        if (! (k in validQueryParams)) { throw new Error("Un-identified operator '" + k + "'");
        }
        this[k](params[k]);
      }
      return this;
    }
};

QueryBuilder._createFromJsonFn = function (QueryBuilderKlass) {
  return function (json) {
    var q = new QueryBuilderKlass;
    for (var param in json) {
      switch (param) {
        case 'type':
          QueryBuilder.prototype[json[param]].call(q);
          break;
        case 'from':
        case 'byId':
        case 'sort':
        case 'skip':
        case 'limit':
          q[param](json[param]);
          break;
        case 'only':
        case 'except':
          q[param](json[param]);
          break;
        case 'equals':
        case 'notEquals':
        case 'gt':
        case 'gte':
        case 'lt':
        case 'lte':
        case 'within':
        case 'contains':
        case 'exists':
          var fields = json[param];
          for (var field in fields) {
            q.where(field)[param](fields[field]);
          }
          break;
        default:
          throw new Error("Un-identified Query json property '" + param + "'");
      }
    }
    return q;
  }
};

QueryBuilder.fromJson = QueryBuilder._createFromJsonFn(QueryBuilder);

// We use ABBREVS for query hashing, so our hashes are more compressed.
var ABBREVS = {
        equals: '$eq'
      , notEquals: '$ne'
      , gt: '$gt'
      , gte: '$gte'
      , lt: '$lt'
      , lte: '$lte'
      , within: '$w'
      , contains: '$c'
      , exists: '$x'

      , byId: '$id'

      , only: '$o'
      , except: '$e'
      , sort: '$s'
      , asc: '^'
      , desc: 'v'
      , skip: '$sk'
      , limit: '$L'
    }
  , SEP = ':';

function noDots (path) {
  return path.replace(/\./g, '$DOT$');
}

// TODO Close ABBREVS with reverse ABBREVS?
QueryBuilder.hash = function (json, filterFn) {
  var groups = []
    , typeHash
    , nsHash
    , byIdHash
    , selectHash
    , sortHash
    , skipHash
    , limitHash
    , group
    , fields, field;

  for (var method in json) {
    var val = json[method];
    switch (method) {
      case 'type':
        typeHash = json[method];
        break;
      case 'from':
        nsHash = noDots(val);
        break;
      case 'byId':
        byIdHash = ABBREVS.byId + SEP + JSON.stringify(val);
        break;
      case 'only':
      case 'except':
        selectHash = ABBREVS[method];
        for (var i = 0, l = val.length; i < l; i++) {
          field = val[i];
          selectHash += SEP + noDots(field);
        }
        break;
      case 'sort':
        sortHash = ABBREVS.sort + SEP;
        for (var i = 0, l = val.length; i < l; i+=2) {
          field = val[i];
          sortHash += noDots(field) + SEP + ABBREVS[val[i+1]];
        }
        break;
      case 'skip':
        skipHash = ABBREVS.skip + SEP + val;
        break;
      case 'limit':
        limitHash = ABBREVS.limit + SEP + val;
        break;

      case 'where':
        break;
      case 'within':
      case 'contains':
        for (var k in val) {
          val[k] = val[k].sort();
        }
        // Intentionally fall-through without a break
      case 'equals':
      case 'notEquals':
      case 'gt':
      case 'gte':
      case 'lt':
      case 'lte':
      case 'exists':
        group = [ABBREVS[method]];
        fields = group[group.length] = [];
        groups.push(group);
        for (field in val) {
          fields.push([field, JSON.stringify(val[field])]);
        }
        break;
    }
  }

  var hash = nsHash + SEP + typeHash;
  if (byIdHash)  hash += SEP + byIdHash;
  if (sortHash)   hash += SEP + sortHash;
  if (selectHash) hash += SEP + selectHash;
  if (skipHash)   hash += SEP + skipHash;
  if (limitHash)  hash += SEP + limitHash;

  for (var i = groups.length; i--; ) {
    group = groups[i];
    group[1] = group[1].sort(comparator);
  }

  groups = groups.sort( function (groupA, groupB) {
    var pathA = groupA[0]
      , pathB = groupB[0];
    if (pathA < pathB)   return -1;
    if (pathA === pathB) return 0;
    return 1;
  });

  for (i = 0, l = groups.length; i < l; i++) {
    group = groups[i];
    hash += SEP + SEP + group[0];
    fields = group[1];
    for (var j = 0, m = fields.length; j < m; j++) {
      var pair = fields[j]
        , field = pair[0]
        , val   = pair[1];
      hash += SEP + noDots(field) + SEP + val;
    }
  }

  if (filterFn) {
    // TODO: Do a less ghetto hash function here
    hash += SEP + 'filterFn' + SEP +
      filterFn.toString().replace(/[\s(){},.]/g, function(match) {
        return match.charCodeAt(0);
      });
  }

  return hash;
};

proto.hash = function hash () {
  return QueryBuilder.hash(this._json);
};

function comparator (pairA, pairB) {
  var methodA = pairA[0], methodB = pairB[0];
  if (methodA < methodB)   return -1;
  if (methodA === methodB) return 0;
  return 1;
}

proto.sort = function (params) {
  if (arguments.length > 1) {
    params = Array.prototype.slice.call(arguments);
  }
  this._json.sort = params;
  return this;
};

var methods = [
    'skip'
  , 'limit'
];

methods.forEach( function (method) {
  proto[method] = function (arg) {
    this._json[method] = arg;
    return this;
  }
});

methods = ['only', 'except'];

methods.forEach( function (method) {
  proto[method] = function (paths) {
    if (arguments.length > 1 || ! Array.isArray(arguments[0])) {
      paths = Array.prototype.slice.call(arguments);
    }
    var json = this._json
      , fields = json[method] || (json[method] = {});
    if (Array.isArray(paths)) {
      for (var i = paths.length; i--; ) {
        fields[paths[i]] = 1;
      }
    } else if (paths.constructor === Object) {
      merge(fields, paths);
    } else {
      console.error(paths);
      throw new Error('Un-supported paths format');
    }
    return this;
  }
});

methods = [
    'equals'
  , 'notEquals'
  , 'gt', 'gte', 'lt', 'lte'
  , 'within', 'contains'
];

methods.forEach( function (method) {
  // Each method `equals`, `notEquals`, etc. just populates a `json` property
  // that is a JSON representation of the query that can be passed around
  proto[method] = function (val) {
    var json = this._json
      , cond = json[method] || (json[method] = {});
    cond[this._currField] = val;
    return this;
  };
});

proto.exists = function (val) {
  var json = this._json
    , cond = json.exists || (json.exists = {});
  cond[this._currField] = (!arguments.length)
                        ? true // exists() is shorthand for exists(true)
                        : val;
  return this;
};

var queryTypes = require('./types')
  , registerType = require('./types/register');
for (var t in queryTypes) {
  registerType(QueryBuilder, t, queryTypes[t]);
}
