var QueryBuilder = require('./QueryBuilder')
  , bundleUtils = require('../../bundle/util')
  , bundledFunction = bundleUtils.bundledFunction
  , unbundledFunction = bundleUtils.unbundledFunction
  , deepCopy = require('../../util').deepCopy
  ;

module.exports = QueryMotifRegistry;

/**
 * Instantiates a `QueryMotifRegistry`. The instance is used by Model and Store
 * to add query motifs and to generate QueryBuilder instances with the
 * registered query motifs.
 */
function QueryMotifRegistry () {
  // Contains the query motifs declared without a ns.
  // An example this._noNs might look like:
  //     this._noNs = {
  //       motifNameK: callbackK
  //     , motifNameL: callbackL
  //     };
  // This would have been generated via:
  //     this.add('motifNameK', callbackK);
  //     this.add('motifNameL', callbackL);
  this._noNs = {};

  // Contains the query motifs declared with an ns.
  // An example this._byNs might look like:
  //     this._byNs = {
  //       nsA: {
  //         motifNameX: callbackX
  //       , motifNameY: callbackY
  //       }
  //     , nsB: {
  //         motifNameZ: callbackZ
  //       }
  //     };
  // This would have been generated via:
  //     this.add('nsA', 'motifNameX', callbackX);
  //     this.add('nsA', 'motifNameY', callbackY);
  //     this.add('nsB', 'motifNameZ', callbackZ);
  this._byNs = {};

  // An index of factory methods that generate query representations of the form:
  //
  //     { tuple: [ns, {motifName: queryArgs}]}
  //
  // This generated query representation prototypically inherits from
  // this._tupleFactories[ns] in order to compose queries from > 1 query
  // motifs in a chained manner.
  //
  // An example this._tupleFactories might look like:
  //
  //     this._tupleFactories = {
  //       nsA: {
  //         motifNameX: factoryX
  //       }
  //     }
  this._tupleFactories = {};
}

/**
 * Creates a QueryMotifRegistry instance from json that has been generated from
 * QueryMotifRegistry#toJSON
 *
 * @param {Object} json
 * @return {QueryMotifRegistry}
 * @api public
 */
QueryMotifRegistry.fromJSON = function (json) {
  var registry = new QueryMotifRegistry
    , noNs = registry._noNs = json['*'];

  _register(registry, noNs);

  delete json['*'];
  for (var ns in json) {
    var callbacksByName = json[ns];
    _register(registry, callbacksByName, ns);
  }
  return registry;
};

function _register (registry, callbacksByName, ns) {
  for (var motifName in callbacksByName) {
    var callbackStr = callbacksByName[motifName]
      , callback = unbundledFunction(callbackStr);
    if (ns) registry.add(ns, motifName, callback);
    else    registry.add(motifName, callback);
  }
}

QueryMotifRegistry.prototype ={
  /**
   * Registers a query motif.
   *
   * @optional @param {String} ns is the namespace
   * @param {String} motifName is the name of the nquery motif
   * @param {Function} callback
   * @api public
   */
  add: function (ns, motifName, callback) {
    if (arguments.length === 2) {
      callback = motifName;
      motifName = ns
      ns = null;
    }
    var callbacksByName;
    if (ns) {
      var byNs = this._byNs;
      callbacksByName = byNs[ns] || (byNs[ns] = Object.create(this._noNs));
    } else {
      callbacksByName = this._noNs;
    }
    if (callbacksByName.hasOwnProperty(motifName)) {
      throw new Error('There is already a query motif "' + motifName + '"');
    }
    callbacksByName[motifName] = callback;

    var tupleFactories = this._tupleFactories;
    tupleFactories = tupleFactories[ns] || (tupleFactories[ns] = Object.create(tupleFactoryProto));

    tupleFactories[motifName] = function addToTuple () {
      var args = Array.prototype.slice.call(arguments);
      // deepCopy the args in case any of the arguments are direct references
      // to an Object or Array stored in our Model Memory. If we don't do this,
      // then we can end up having the query change underneath the registry,
      // which causes problems because the rest of our code expects the
      // registry to point to an immutable query.
      this.tuple[1][motifName] = deepCopy(args);
      return this;
    };
  }

  /**
   * Unregisters a query motif.
   *
   * @optional @param {String} ns is the namespace
   * @param {String} motifName is the name of the query motif
   * @api public
   */
, remove: function (ns, motifName) {
    if (arguments.length === 1) {
      motifName = ns
      ns = null;
    }
    var callbacksByName
      , tupleFactories = this._tupleFactories;
    if (ns) {
      var byNs = this._byNs;
      callbacksByName = byNs[ns];
      if (!callbacksByName) return;
      tupleFactories = tupleFactories[ns];
    } else {
      callbacksByName = this.noNs;
    }
    if (callbacksByName.hasOwnProperty(motifName)) {
      delete callbacksByName[motifName];
      if (ns && ! Object.keys(callbacksByName).length) {
        delete byNs[ns];
      }
      delete tupleFactories[motifName];
      if (! Object.keys(tupleFactories).length) {
        delete this._tupleFactories[ns];
      }
    }
  }

  /**
   * Returns an object for composing queries in a chained manner where the
   * chainable methods are named after query motifs registered with a ns.
   *
   * @param {String} ns
   * @return {Object}
   */
, queryTupleBuilder: function (ns) {
    var tupleFactories = this._tupleFactories[ns];
    if (!tupleFactories) {
      throw new Error('You have not declared any query motifs for the namespace "' + ns + '"' +
                      '. You must do so via store.query.expose before you can query a namespaced ' +
                      'collection of documents');
    }
    return Object.create(tupleFactories, {
      tuple: { value: [ns, {}, null] }
    });
  }

  /**
   * Returns a json representation of the query, based on queryTuple and which
   * query motifs happen to be registered at the moment via past calls to
   * QueryMotifRegistry#add.
   *
   * @param {Array} queryTuple is [ns, {motifName: queryArgs}, queryId]
   * @return {Object}
   * @api public
   */
, queryJSON: function (queryTuple) {
    // Instantiate a QueryBuilder.
    // Loop through the motifs of the queryTuple, and apply the corresponding motif logic to augment the QueryBuilder.
    // Tack on the query type in the queryTuple (e.g., 'one', 'count', etc.), if
  // specified -- otherwise, default to 'find' type.
    // Convert the QueryBuilder instance to json
    var ns = queryTuple[0]
      , queryBuilder = new QueryBuilder({from: ns})

      , queryComponents = queryTuple[1]
      , callbacksByName = this._byNs[ns]
      ;

    for (var motifName in queryComponents) {
      var callback = callbacksByName
                   ? callbacksByName[motifName]
                   : this._noNs[motifName];
      if (! callback) return null;
      var queryArgs = queryComponents[motifName];
      callback.apply(queryBuilder, queryArgs);
    }

    // A typeMethod (e.g., 'one', 'count') declared in query motif chaining
    // should take precedence over any declared inside a motif definition callback
    var typeMethod = queryTuple[2];
    if (typeMethod) queryBuilder[typeMethod]();

    // But if neither the query motif chaining nor the motif definition define
    // a query type, then default to the 'find' query type.
    if (! queryBuilder.type) queryBuilder.find();

    return queryBuilder.toJSON();
  }

  /**
   * Returns a JSON representation of the registry.
   *
   * @return {Object} JSON representation of `this`
   * @api public
   */
, toJSON: function () {
    var json = {}
      , noNs = this._noNs
      , byNs = this._byNs;

    // Copy over query motifs not specific to a namespace
    var curr = json['*'] = {};
    for (var k in noNs) {
      curr[k] = noNs[k].toString();
    }

    // Copy over query motifs specific to a namespace
    for (var ns in byNs) {
      curr = json[ns] = {};
      var callbacks = byNs[ns];
      for (k in callbacks) {
        var cb = callbacks[k];
        curr[k] = bundledFunction(cb);
      }
    }

    return json;
  }

  /**
   * @param {String} ns is the collection namespace
   * @param {String} motifName is the name of the QueryMotif
   * @return {Number} the arity of the query motif definition callback
   */
, arglen: function (ns, motifName) {
    var cbsByMotif = this._byNs[ns];
    if (!cbsByMotif) return;
    var cb = cbsByMotif[motifName];
    return cb && cb.length;
  }
}

var queryTypes = require('./types');
var tupleFactoryProto = {};
for (var t in queryTypes) {
  (function (t) {
    // t could be: 'find', 'one', 'count', etc. -- see ./types
    tupleFactoryProto[t] = function () {
      this.tuple[2] = t;
      return this;
    };
  })(t);
}
