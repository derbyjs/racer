var basePattern = require('./base')
  , mergeAll = require('../../util').mergeAll
  , setupQueryModelScope = require('./scope')

  , transaction = require('../../transaction')
  , QueryBuilder = require('./QueryBuilder')
  , QueryRegistry = require('./QueryRegistry')
  , QueryMotifRegistry = require('./QueryMotifRegistry')
  ;

module.exports = {
  type: 'Model'
, events: {
    init: onInit
  , bundle: onBundle
  , socket: onSocket
  }
, decorate: function (Model) {
    var modelPattern = mergeAll({
      scopedResult: scopedResult
    , registerSubscribe: registerSubscribe
    , registerFetch: registerFetch
    , unregisterSubscribe: unregisterSubscribe
    , subs: subs
    }, basePattern);
    Model.dataDescriptor(modelPattern);
  }
, proto: {
    _loadQueries: loadQueries
  , _querySubs: querySubs
  , queryJSON: queryJSON
  , _loadQueryMotifs: loadQueryMotifs
  , registerQuery: registerQuery
  , unregisterQuery: unregisterQuery
  , registeredMemoryQuery: registeredMemoryQuery
  , registeredQueryId: registeredQueryId
  , fromQueryMotif: fromQueryMotif
  , query: query
  }
};


function onInit(model) {
  var store = model.store;
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

function onBundle(model, addToBundle) {
  // TODO Re-write this
  var queryMotifRegistry = model._queryMotifRegistry
    , queryMotifBundle = queryMotifRegistry.toJSON();
  model._onLoad.push(['_loadQueryMotifs', queryMotifBundle]);
  addToBundle('_loadQueries', model._queryRegistry.bundle());
}

function onSocket(model, socket) {
  var memory = model._memory;

  // The "addDoc" event is fired wheneber a remote mutation results in a
  // new or existing document in the cloud to become a member of one of the
  // result sets corresponding to a query that this model is currently
  // subscribed.
  socket.on('addDoc', function (payload, num) {
    var data = payload.data
      , doc = data.doc
      , ns  = data.ns
      , ver = data.ver
      , txn = data.txn
      , collection = model.get(ns);

    // If the doc is already in the model, don't add it
    if (collection && collection[doc.id]) {
      // But apply the transaction that resulted in the document that is
      // added to the query result set.
      if (transaction.getClientId(txn) === model._clientId) {
        // Set to null txn, and still account for num
        txn = null
      }
      return model._addRemoteTxn(txn, num);
    }

    var pathToDoc = ns + '.' + doc.id
      , txn = transaction.create({
          ver: ver
        , id: null
        , method: 'set'
        , args: [pathToDoc, doc]
        });
    model._addRemoteTxn(txn, num);
    model.emit('addDoc', pathToDoc, doc);
  });

  // The "rmDoc" event is fired wheneber a remote mutation results in an
  // existing document in the cloud ceasing to become a member of one of
  // the result sets corresponding to a query that this model is currently
  // subscribed.
  socket.on('rmDoc', function (payload, num) {
    var hash = payload.channel // TODO Remove
      , data = payload.data
      , doc  = data.doc
      , id   = data.id
      , ns   = data.ns
      , ver  = data.ver
      , txn = data.txn

        // TODO Maybe just [clientId, queryId]
      , queryTuple = data.q; // TODO Add q to data

    // Don't remove the doc if any other queries match the doc
    var querySubs = model._querySubs();
    for (var i = querySubs.length; i--; ) {
      var currQueryTuple = querySubs[i];

      var memoryQuery = model.registeredMemoryQuery(currQueryTuple);

      // If "rmDoc" was triggered by the same query, we expect it not to
      // match the query, so ignore it.
      if (QueryBuilder.hash(memoryQuery.toJSON()) === hash.substring(3, hash.length)) continue;

      // If the doc belongs in an existing subscribed query's result set,
      // then don't remove it, but instead apply a "null" transaction to
      // make sure the transaction counter `num` is acknowledged, so other
      // remote transactions with a higher counter can be applied.
      if (memoryQuery.filterTest(doc, ns)) {
        return model._addRemoteTxn(null, num);
      }
    }

    var pathToDoc = ns + '.' + id
      , oldDoc = model.get(pathToDoc);
    if (transaction.getClientId(txn) === model._clientId) {
      txn = null;
    } else {
      txn = transaction.create({
          ver: ver
        , id: null
        , method: 'del'
        , args: [pathToDoc]
      });
    }

    model._addRemoteTxn(txn, num);
    model.emit('rmDoc', pathToDoc, oldDoc);
  });
}


function scopedResult(model, queryTuple) {
  var memoryQuery = model.registeredMemoryQuery(queryTuple)
    , queryId = model.registeredQueryId(queryTuple);
  return setupQueryModelScope(model, memoryQuery, queryId);
}
function registerSubscribe(model, queryTuple) {
  model.registerQuery(queryTuple, 'subs');
}
function registerFetch(model, queryTuple) {
  model.registerQuery(queryTuple, 'fetch');
}
function unregisterSubscribe(model, queryTuple) {
  var querySubs = model._querySubs()
    , hash = QueryBuilder.hash(queryJson);
  if (! (hash in querySubs)) return;
  model.unregisterQuery(hash, querySubs);
}
function subs(model) {
  return model._querySubs();
}

function loadQueries(bundle) {
  for (var i = 0, l = bundle.length; i < l; i++) {
    var pair = bundle[i]
      , queryTuple = pair[0]
      , tag = pair[1];
    var force = true;
    this.registerQuery(queryTuple, tag, force);
    scopedResult(this, queryTuple);
  }
}
function querySubs() {
  return this._queryRegistry.lookupWithTag('subs');
}

/**
 * @param {Array} queryTuple
 * @return {Object} json representation of the query
 * @api protected
 */
function queryJSON(queryTuple) {
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
function loadQueryMotifs(queryMotifBundle) {
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
function registerQuery(queryTuple, tag, force) {
  var queryRegistry = this._queryRegistry
    , queryId = queryRegistry.add(queryTuple, this._queryMotifRegistry, force) ||
                queryRegistry.queryId(queryTuple);
  queryRegistry.tag(queryId, tag);
  if (!tag) throw new Error("NO TAG");
  return queryId;
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
function unregisterQuery(queryTuple, tag) {
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
function registeredMemoryQuery(queryTuple) {
  return this._queryRegistry.memoryQuery(queryTuple, this._queryMotifRegistry);
}

function registeredQueryId(queryTuple) {
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
function fromQueryMotif(/* motifName, queryArgs... */) {
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
 *  You do not need to pass query to subscribe. You can also call subscribe
 *  on the query directly:
 *
 *      model.query('todos').forUser('1').subscribe( function (err, todos) {
 *        console.log(todos.get());
 *      });
 *
 *  This also supports a function signature that's better for
 *  coffee-script:
 *
 *  Example in coffee:
 *
 *     model.query 'todos',
 *       forUser: '1'
 *       subscribe: (err, todos) ->
 *         console.log todos.get()
 *
 * @param {String} ns
 * @return {Object} a query tuple builder
 * @api public
 */
function query(ns) {
  var model = this;
  var builder = Object.create(this._queryMotifRegistry.queryTupleBuilder(ns), {
    fetch: {value: function (cb) {
      model.fetch(this, cb);
    }}
  , waitFetch: {value: function (cb) {
      model.waitFetch(this, cb);
    }}
  , subscribe: {value: function (cb) {
      model.subscribe(this, cb);
    }}
  });
  if (arguments.length == 2) {
    var params = arguments[1];
    var getter = 'fetch' in params
               ? 'fetch'
               : 'subscribe' in params
                 ? 'subscribe'
                 : null;
    if (getter) {
      var cb = params[getter];
      delete params[getter];
    }
    for (var motif in params) {
      builder[motif](params[motif]);
    }
    if (getter) builder[getter](cb);
  }
  return builder;
}
