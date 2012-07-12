var transaction = require('../transaction')
  , QueryBuilder = require('../queries/QueryBuilder')
  , compileTargets = require('../queries/util').compileTargets
  , noop = require('../util').noop
  ;

module.exports = {
  type: 'Model'

, events: {
    init: function (model) {
      // `_pathSubs` remembers path subscriptions.
      // This memory is useful when the client may have been
      // disconnected from the server for quite some time and needs to re-send
      // its subscriptions upon re-connection in order for the server (1) to
      // figure out what data the client needs to re-sync its snapshot and (2)
      // to re-subscribe to the data on behalf of the client. The paths and
      // queries get cached in Model#subscribe.
      model._pathSubs  = {}; // path -> Boolean
    }

  , bundle: function (model, addToBundle) {
      addToBundle('_loadSubs', model._pathSubs, model._querySubs());
    }

  , socket: function (model, socket) {
      var memory = model._memory;

      // The "addDoc" event is fired whenever a remote mutation results in a
      // new or existing document in the cloud to become a member of one of the
      // result sets corresponding to a query that this model is currently subscribed.
      socket.on('addDoc', function (payload, num) {
        var data = payload.data
          , doc = data.doc
          , ns  = data.ns
          , ver = data.ver
          , txn = data.txn
          , collection = memory.get(ns);

        // If the doc is already in the model, don't add it
        if (collection && collection[doc.id]) {
          // But apply the transaction that resulted in the document that is
          // added to the query result set.
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
          , txn = transaction.create({
                ver: ver
              , id: null
              , method: 'del'
              , args: [pathToDoc]
            })
          , oldDoc = model.get(pathToDoc);
        model._addRemoteTxn(txn, num);
        model.emit('rmDoc', pathToDoc, oldDoc);
      });
    }
  }

, proto: {
    _loadSubs: function (pathSubs, querySubList) {
      this._pathSubs = pathSubs;

      var querySubs = this._querySubs();
      for (var i = querySubs.length; i--; ) {
        var queryTuple = querySubs[i];
        this.registerQuery(queryTuple, 'subs');
      }
    }

  , _querySubs: function () {
      return this._queryRegistry.lookupWithTag('subs');
    }

  , subscribe: function (/* targets..., callback */) {
      var arglen = arguments.length
        , lastArg = arguments[arglen-1]
        , callback = (typeof lastArg === 'function') ? lastArg : noop
        , targets = Array.prototype.slice.call(arguments, 0, callback ? arglen-1 : arglen)

        , pathSubs = this._pathSubs
        , querySubs = this._querySubs()
        , self = this
        ;
      compileTargets(targets, {
        model: this
      , eachQueryTarget: function (queryTuple, targets) {
          self.registerQuery(queryTuple, 'subs');
        }
      , eachPathTarget: function (path, targets) {
          if (path in pathSubs) return;
          pathSubs[path] = true;
        }
      , done: function (targets, modelScopes) {
          if (! targets.length) {
            return callback.apply(null, [null].concat(modelScopes));
          }
          self._addSub(targets, function (err, data) {
            if (err) return callback(err);
            self._addData(data);
            self.emit('addSubData', data);
            callback.apply(self, [null].concat(modelScopes));
          });
        }
      });
    }

  , unsubscribe: function (/* targets..., callback */) {
      var arglen = arguments.length
        , lastArg = arguments[arglen-1]
        , callback = (typeof lastArg === 'function') ? lastArg : noop
        , targets = Array.prototype.slice.call(arguments, 0, callback ? arglen-1 : arglen)

        , pathSubs = this._pathSubs
        , querySubs = this._querySubs()
        , self = this
        ;

      compileTargets(targets, {
        model: this
      , eachQueryTarget: function (queryJson) {
          var hash = QueryBuilder.hash(queryJson);
          if (! (hash in querySubs)) return;
          self.unregisterQuery(hash, querySubs);
        }
      , eachPathTarget: function (path, targets) {
          if (! (path in pathSubs)) return;
          delete pathSubs[path];
        }
      , done: function (targets) {
          if (! targets.length) return callback();
          self._removeSub(targets, callback);
        }
      });
    }

  , _addSub: function (targets, cb) {
      if (! this.connected) return cb('disconnected');
      this.socket.emit('subscribe', targets, this.scopedContext, cb);
    }

  , _removeSub: function (targets, cb) {
      if (! this.connected) return cb('disconnected');
      this.socket.emit('unsubscribe', targets, cb);
    }

    // TODO Associate contexts with path and query subscriptions
  , _subs: function () {
      var subs = Object.keys(this._pathSubs)
        , querySubs = this._querySubs();
      for (var i = querySubs.length; i--; ) {
        var queryTuple = querySubs[i];
        subs.push(queryTuple);
      }
      return subs;
    }
  }

, server: {
    _addSub: function (targets, cb) {
      var store = this.store
        , contextName = this.scopedContext
        , self = this;
      this._clientIdPromise.on( function (err, clientId) {
        if (err) return cb(err);
        // Subscribe while the model still only resides on the server.
        // The model is unsubscribed before sending to the browser.
        var req = {
          clientId: clientId
        , session: self.session
        , targets: targets
        , context: store.context(contextName)
        };
        var res = {
          fail: cb
        , send: function (data) {
            cb(null, data);
          }
        };
        store.middleware.subscribe(req, res);
      });
    }

  , _removeSub: function (targets, cb) {
      var store = this.store
        , context = this.scopedContext
      this._clientIdPromises.on( function (err, clientId) {
        if (err) return cb(err);
        var mockSocket = { clientId: clientId };
        store.unsubscribe(mockSocket, targets, context, cb);
      });
    }
  }
};
