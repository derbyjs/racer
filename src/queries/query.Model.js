var EventEmitter = require('events').EventEmitter
  , QueryBuilder = require('./QueryBuilder')
  , QueryRegistry = require('./QueryRegistry')
  , QueryMotifRegistry = require('./QueryMotifRegistry')
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
      var store = model.store
      if (store) {
        // Maps query motif -> callback
        model._queryMotifRegistry = store._queryMotifRegistry;
      } else {
        // Stores any query motifs registered via store.query.expose. The query
        // motifs declared via Store are copied over to all child Model
        // instances created via Store#createModel
        model._queryMotifRegistry = new QueryMotifRegistry;
      }

      // The query registry stores any queries associated with the model via
      // Model#fetch and Model#subscribe
      model._queryRegistry = new QueryRegistry;
    }

    // TODO Re-write this
  , bundle: function (model) {
      var queryMotifRegistry = model._queryMotifRegistry
        , queryMotifBundle = queryMotifRegistry.toJSON();
      model._onLoad.push(['_loadQueryMotifs', queryMotifBundle]);
    }
  }
, proto: {

    /**
     * @param {Array} queryTuple
     * @return {Object} json representation of the query
     * @api protected
     */
    queryJSON: function (queryTuple) {
      return this._queryMotifRegistry.queryJSON(queryTuple);
    }

    /**
     * Called when loading the model bundle. Loads queries defined by store.query.expose
     *
     * @param {Object} queryMotifBundle is the bundled form of a
     * QueryMotifRegistry, that was packaged up by the server Model and sent
     * down with the initial page response.
     * @api private
     */
  , _loadQueryMotifs: function (queryMotifBundle) {
      this._queryMotifRegistry = QueryMotifRegistry.fromJSON(queryMotifBundle);
    }

    /**
     * Registers queries to which the model is subscribed.
     *
     * @param {Array} queryTuple
     * @param {String} tag to label the query
     * @return {Boolean} true if registered; false if already registered
     * @api protected
     */
  , registerQuery: function (queryTuple, tag) {
      var queryRegistry = this._queryRegistry
        , queryId = queryRegistry.add(queryTuple) ||
                    queryRegistry.queryId(queryTuple)
        , tagged = tag && queryRegistry.tag(queryId, tag);
      return tagged || queryId;
    }

    /**
     * If no tag is provided, removes queries that we do not care to keep around anymore.
     * If a tag is provided, we only untag the query.
     *
     * @param {Array} queryTuple of the form [motifName, queryArgs...]
     * @param {Object} index mapping query hash -> Boolean
     * @return {Boolean}
     * @api protected
     */
  , unregisterQuery: function (queryTuple, tag) {
      var queryRegistry = this._queryRegistry;
      if (tag) {
        var queryId = queryRegistry.queryId(queryTuple);
        return queryRegistry.untag(queryId, tag);
      }
      return queryRegistry.remove(queryTuple);
    }

    /**
     * Locates a registered query.
     *
     * @param {String} motifName
     * @return {MemoryQuery|undefined} the registered MemoryQuery matching the queryRepresentation
     * @api protected
     */
  , registeredMemoryQuery: function (queryTuple) {
      return this._queryRegistry.memoryQuery(queryTuple, this._queryMotifRegistry);
    }

  , registeredQueryId: function (queryTuple) {
      return this._queryRegistry.queryId(queryTuple);
    }

    /**
     * Convenience method for generating [motifName, queryArgs...] tuples to
     * pass to Model#subscribe and Model#fetch.
     *
     * Example:
     *
     *     var query = model.fromQueryMotif('todos', 'forUser', 'someUserId');
     *     model.subscribe(query, function (err, todos) {
     *       console.log(todos.get());
     *     });
     *
     * @param {String} motifName
     * @param @optional {Object} queryArgument1
     * @param @optional {Object} ...
     * @param @optional {Object} queryArgumentX
     * @return {Array} a tuple of [null, motifName, queryArguments...]
     * @api public
     */
  , fromQueryMotif: function (/* motifName, queryArgs... */) {
      return [null].concat(Array.prototype.slice.call(arguments, 0));
    }

    /**
     * Convenience method for generating [ns, [motifName, queryArgs...],
     * [motifName, queryArgs...]] tuples to pass to Model#subscribe and
     * Model#fetch via a fluent, chainable interface.
     *
     * Example:
     *
     *     var query = model.query('todos').forUser('1');
     *     model.subscribe(query, function (err, todos) {
     *       console.log(todos.get());
     *     });
     *
     * @param {String} ns
     * @return {Object} a query tuple builder
     * @api public
     */
  , query: function (ns) {
      return this._queryMotifRegistry.queryTupleBuilder(ns);
    }

    /**
     * fetch(targets..., callback)
     * Fetches targets which represent a set of paths, path patterns, and/or
     * queries.
     *
     * @param {String|Array} targets[0] representing a path, path pattern, or query
     * @optional @param {String|Array} targets[1] representing a path, path pattern,
     *                                 or query
     * @optional @param {String|Array} ...
     * @optional @param {String|Array} targets[k] representing a path, path pattern,
     *                                 or query
     * @param {Function} callback
     * @api public
     */
  , fetch: function () {
      var arglen = arguments.length
        , lastArg = arguments[arglen-1]
        , callback = (typeof lastArg === 'function') ? lastArg : noop
        , targets = Array.prototype.slice.call(arguments, 0, callback ? arglen-1 : arglen);

      this._compileTargets(targets, {
        done: function (targets, scopedModels) { /* this === model */
          var self = this;
          self._waitOrFetchData(targets, function (err, data) {
            self._addData(data);
            callback.apply(null, [err].concat(scopedModels));
          });
        }
      });
    }

  , _addData: function (data) {
      var memory = this._memory
        , data = data.data;
      for (var i = data.length; i--; ) {
        var triplet = data[i]
          , path = triplet[0]
          , value = triplet[1]
          , ver = triplet[2];
        memory.set(path, value, ver);
      }
    }

    /**
     * Fetches the path and/or query targets and passes the result(s) to the callback.
     *
     * @param {Array} targets are an Array of paths and/or queries
     * @param {Function} callback(err, data, ver) where data is an array of
     * pairs of the form [path, dataAtPath]
     * @api protected
     */
  , _waitOrFetchData: function (targets, callback) {
      if (!this.connected) return callback('disconnected');
      this.socket.emit('fetch', targets, callback);
    }

    /**
     * @param {Array} targets have members who are either Strings representing
     * paths or path patterns OR Arrays representing query tuples of the form
     * [motifName, queryArgs...]
     * @param {Object} opts
     * @api private
     */
  , _compileTargets: function (targets, opts) {
      var done = opts.done /* done(targets) or done(targets, scopes) */
        , compileScopedModels = (done.length === 2)
        , parser = new EventEmitter
        , expandedTargets = []
        , model = this;

      var eachPathTarget = opts.eachPathTarget;
      parser.on('path', function (path) {
        eachPathTarget && eachPathTarget.call(model, path);
        // TODO push unexpanded target or expanded path?
        expandedTargets.push(path);
      });

      var eachQueryTarget = opts.eachQueryTarget;
      parser.on('query', function (queryTuple) {
        eachQueryTarget && eachQueryTarget.call(model, queryTuple);
        expandedTargets.push(queryTuple);
      });

      if (compileScopedModels) {
        // Compile the list of model scopes representative of the fetched
        // results to pass back to opts.done
        var scopedModels = [];
        parser.on('pattern', function (pattern) {
          // TODO This does not always calc pathUpToGlob
          var pathUpToGlob = splitPath(pattern)[0]
            , scopedModel = model.at(pathUpToGlob);
          scopedModels.push(scopedModel);
        });
        parser.on('query', function (queryTuple) {
          var memoryQuery = model.registeredMemoryQuery(queryTuple)
            , queryId = model.registeredQueryId(queryTuple)
            , scopedModel = setupQueryModelScope(model, memoryQuery, queryId);
          scopedModels.push(scopedModel);
        });
        parser.on('done', function () {
          done.call(model, expandedTargets, scopedModels);
        });
      } else {
        parser.on('done', function () {
          done.call(model, expandedTargets);
        });
      }

      parseTargets(parser, targets);
    }
  }

, server: {
    _waitOrFetchData: function (targets, cb) {
      var store = this.store;
      this._clientIdPromise.on( function (err, clientId) {
        if (err) return cb(err);
        store.fetch(clientId, targets, cb);
      });
    }
  }
};

/**
 * Parses targets into full set of targets. In particular, patterns need to be
 * expanded into paths. As it's parsing, it emits events:
 *
 * - "pattern" for every target that is a path pattern
 * - "path" for every path that belongs to a set of paths derived from a
 *   pattern target
 * - "query" for every target that is a query tuple
 *
 * @param {EventEmitter} parser
 * @param {Array} targets is an array of strings (representing paths and/or
 * patterns) and/or query tuples (i.e., arrays of the form [motifName,
 * queryArgs...]
 */
function parseTargets (parser, targets) {
  for (var i = 0, l = targets.length; i < l; i++) {
    var target = targets[i];

    if (Array.isArray(target)) { /* If target is a query tuple */
      parser.emit('query', target);
    } else if (target.tuple) {
      parser.emit('query', target.tuple);
    } else { /* Else target is a path or model scope */
      if (target._at) target = target._at;
      parser.emit('pattern', target);
      var paths = expandPath(target);
      for (var k = paths.length; k--; ) {
        parser.emit('path', paths[k]);
      }
    }
  }
  parser.emit('done');
}
