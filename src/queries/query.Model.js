var ModelQueryBuilder = require('./ModelQueryBuilder')
  , QueryBuilder = require('./QueryBuilder')
  , path = require('../path')
  , splitPath = path.split
  , expandPath = path.expand
  , queryUtils = require('./util')
  , privateQueryResultAliasPath = queryUtils.privateQueryResultAliasPath
  , privateQueryResultPointerPath = queryUtils.privateQueryResultPointerPath
  ;

module.exports = {
  type: 'Model'
, events: {
    init: function (model) {
      // TODO We use neither of these data structures

      // maps hash -> 1
      model._privateQueries = {}

      // maps hash ->
      //        query: QueryBuilder
      //        memoryQuery: MemoryQuery
      model._queries = {}
    }
  }
, proto: {

    query: function (namespace, queryParams) {
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
        compileModelAliases: true
      , eachQueryTarget: function (queryJson, addToTargets) {
          addToTargets(queryJson);
        }
      , eachPathTarget: function (path, addToTargets) {
          addToTargets(path);
        }
      , done: function (targets, modelAliases, fetchCb) {
          var self = this;
          this._fetch(targets, function (err, data) {
              self._addData(data);
              fetchCb.apply(null, [err].concat(modelAliases));
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
        , argumentsHaveCallback = (typeof last === 'function')
        , cb = argumentsHaveCallback ? last : noop

        , newTargets = []

        , eachQueryTarget = opts.eachQueryTarget
        , eachPathTarget = opts.eachPathTarget
        , done = opts.done
        , compileModelAliases = opts.compileModelAliases;

      if (compileModelAliases) {
        var modelAliases = []
          , aliasPath
          , modelAlias
          , querySubs = this._querySubs;
      }

      function addToTargets (target) {
        newTargets.push(target);
      }

      var i = argumentsHaveCallback ? arglen-1 : arglen;
      // Transform incoming targets into full set of `newTargets`.
      // Compile the list `out` of model aliases representative of the fetched
      // results, to pass back to the callback `cb`
      while (i--) {
        var target = _arguments[i];
        // TODO Reduce to 1 instanceof by making ModelQueryBuilder inherit from QueryBuilder
        if (target instanceof QueryBuilder || target instanceof ModelQueryBuilder) {
          var queryJson = target.toJSON();
          if (compileModelAliases) {
            aliasPath = privateQueryResultAliasPath(queryJson);

            // Refs, assemble!
            var pointerPath = privateQueryResultPointerPath(queryJson);
            if (queryJson.type === 'findOne') {
              // TODO Test findOne single query result
              modelAlias = this.ref(aliasPath, queryJson.from, pointerPath);
            } else {
              modelAlias = this.refList(aliasPath, queryJson.from, pointerPath);
              var hash = QueryBuilder.hash(queryJson)
                , ns = queryJson.from;
              var listener = (function (querySubs, hash, ns, modelAlias, model, pointerPath) {
                return function (id, doc) {
                  var memoryQuery = querySubs[hash]
                  if (! memoryQuery.filterTest(doc, ns)) return;
                  var comparator = memoryQuery._comparator;
                  var currResults = modelAlias.get();
                  if (!comparator) {
                    return model.insert(pointerPath, currResults.length, doc);
                  }
                  for (var k = currResults.length; k--; ) {
                    var currRes = currResults[k];
                    var comparison = comparator(doc, currRes);
                    if (comparison >= 0) {
                      return model.insert(pointerPath, k+1, doc.id);
                    }
                  }
                  return model.insert(pointerPath, 0, doc);
                };
              })(querySubs, hash, ns, modelAlias, this, pointerPath);
              this.on('set', ns + '.*', listener);

              listener = (function (model, pointerPath) {
                return function (id) {
                  var pos = model.get(pointerPath).indexOf(id);
                  if (~pos) model.remove(pointerPath, pos, 1);
                }
              })(this, pointerPath);
              // The 'del' event is triggered by a 'rmDoc'
              this.on('del', ns + '.*', listener);
            }
          }
          eachQueryTarget.call(this, queryJson, addToTargets, aliasPath);
        } else { // Otherwise, target is a path or model alias
          if (target._at) target = target._at;
          if (compileModelAliases) {
            aliasPath = splitPath(target)[0];
            modelAlias = this.at(aliasPath);
          }
          var paths = expandPath(target);
          for (var k = paths.length; k--; ) {
            var path = paths[k];
            eachPathTarget.call(this, path, addToTargets, aliasPath);
          }
        }
        if (compileModelAliases) {
          modelAliases.push(modelAlias, true);
        }
      }

      if (compileModelAliases) {
        done.call(this, newTargets, modelAliases, cb);
      } else {
        done.call(this, newTargets, cb);
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
