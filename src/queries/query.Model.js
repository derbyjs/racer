var ModelQueryBuilder = require('./ModelQueryBuilder')
  , QueryBuilder = require('./QueryBuilder')
  , path = require('../path')
  , splitPath = path.split
  , expandPath = path.expand
  , queryUtils = require('./util')
  , setupQueryModelScope = queryUtils.setupQueryModelScope
  ;

module.exports = {
  type: 'Model'
, events: {
    init: function (model) {
      // A data structure containing all queries of interest to this model.
      //
      // Maps hash -> MemoryQuery
      //        indexes: [Object]
      //        query: MemoryQuery
      model._queries = {}

      // An index of the local queries -- i.e., queries to which the model is
      // not subscribed
      //
      // Maps hash -> Boolean
      model._localQueries = {}
    }
  }
, proto: {

    /**
     * Registers both local queries and queries to which the model is subscribed.
     * @param {MemoryQuery} memoryQuery
     * @param {Object} index is an index of query hashes to a Boolean
     * @return {Boolean} true if registered; false if already registered
     */
    registerQuery: function (memoryQuery, index) {
      var queryJson = memoryQuery.toJSON()
        , hash = QueryBuilder.hash(queryJson)
        , queries = this._queries;
      if (hash in queries) {
        if (hash in index) return false;
        queries[hash].indexes.push(index);
        return index[hash] = true;
      }
      queries[hash] = {
        query: memoryQuery
      , indexes: [index]
      }
      index[hash] = true;
      return true;
    }

  , unregisterQuery: function (queryRepresentation, index) {
      var queries = this._queries
        , hash;
      if (typeof queryRepresentation === 'string') {
        hash = queryRepresentation;
      } else {
        throw new Error('Arguments error');
      }
      if (! (hash in queries)) return false;
      if (! (hash in index)) return false;

      delete index[hash];

      var meta = queries[hash]
        , indexes = meta.indexes
        , position = indexes.indexOf(index);
      if (~position) {
        indexes.splice(position, 1);
      } else {
        throw new Error('Expected index to be in indexes');
      }
      if (indexes.length === 0) {
        delete queries[hash];
      }
      return true;
    }

  , locateQuery: function (queryRepresentation) {
      var hash;
      if (typeof queryRepresentation === 'string') {
        hash = queryRepresentation;
      } else if (queryRepresentation.constructor === Object) {
        hash = QueryBuilder.hash(queryRepresentation);
      } else {
        throw new Error('Query representation must be json or the query hash string');
      }
      var meta = this._queries[hash];
      return meta && meta.query;
    }

  , query: function (namespace, queryParams) {
      queryParams || (queryParams = {});
      queryParams.from = namespace;
      return new ModelQueryBuilder(queryParams, this);
    }

  , findOne: function (namespace, queryParams) {
      queryParams || (queryParams = {});
      queryParams.from = namespace;
      return (new ModelQueryBuilder(queryParams, this)).findOne();
    }

  , find: function (namespace, queryParams) {
      queryParams || (queryParams = {});
      queryParams.from = namespace;
      return (new ModelQueryBuilder(queryParams, this)).find();
    }

    // fetch(targets..., callback)
  , fetch: function () {
      this._compileTargets(arguments, {
        eachQueryTarget: function (queryJson, targets) {
          targets.push(queryJson);
        }
      , eachPathTarget: function (path, targets) {
          targets.push(path);
        }
      , done: function (targets, scopedModels, fetchCb) {
          var self = this;
          this._fetch(targets, function (err, data) {
              self._addData(data);
              fetchCb.apply(null, [err].concat(scopedModels));
          });
        }
      });
    }

  , _fetch: function (targets, cb) {
      if (!this.connected) return cb('disconnected');
      this.socket.emit('fetch', targets, cb);
    }

    // _arguments is an Array-like arguments whose members are either
    // QueryBuilder instances or Strings that represent paths or path patterns
  , _compileTargets: function (_arguments, opts) {
      var arglen = _arguments.length
        , last = _arguments[arglen-1]
        , argsHaveCallback = (typeof last === 'function')
        , callback = argsHaveCallback ? last : noop

        , newTargets = []

        , done = opts.done
          // done(targets, callback) or done(targets, scopes, callback)
        , compileModelScopes = opts.done.length === 3;

      if (compileModelScopes) {
        var scopedModels = [], scopedModel;
      }

      var i = argsHaveCallback ? arglen-1 : arglen;
      // Transform incoming targets into full set of `newTargets`.
      // Compile the list `out` of model scopes representative of the fetched
      // results, to pass back to the `callback`
      while (i--) {
        var target = _arguments[i];
        var scopedModel = (target instanceof QueryBuilder)
          ? handleQueryTarget(this, target, opts.eachQueryTarget, compileModelScopes, newTargets)

            // Otherwise, target is a path or model scope
          : handlePatternTarget(this, target, opts.eachPathTarget, compileModelScopes, newTargets);
        if (compileModelScopes) {
          scopedModels.unshift(scopedModel);
        }
      }

      if (compileModelScopes) {
        done.call(this, newTargets, scopedModels, callback);
      } else {
        done.call(this, newTargets, callback);
      }
    }
  }
, server: {
    _fetch: function (targets, cb) {
      var store = this.store;
      this._clientIdPromise.on( function (err, clientId) {
        if (err) return cb(err);
        store.fetch(clientId, targets, cb);
      });
    }
  }
};

function handleQueryTarget (model, target, eachQueryTarget, compileModelScopes, newTargets) {
  var queryJson = target.toJSON()
    , scopedModel;
  if (compileModelScopes) {
    scopedModel = setupQueryModelScope(model, queryJson);
  }
  eachQueryTarget.call(model, queryJson, newTargets);
  return scopedModel;
}

function handlePatternTarget (model, target, eachPathTarget, compileModelScopes, newTargets) {
  var scopedModel;
  if (target._at) target = target._at;
  if (compileModelScopes) {
    var refPath = splitPath(target)[0];
    scopedModel = model.at(refPath);
  }
  var paths = expandPath(target);
  for (var k = paths.length; k--; ) {
    var path = paths[k];
    eachPathTarget.call(model, path, newTargets);
  }
  return scopedModel;
}
