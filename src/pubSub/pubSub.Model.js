var transaction = require('../transaction')
  , path = require('../path')
  , expandPath = path.expand
  , splitPath = path.split
  , QueryBuilder = require('../queries/QueryBuilder')
  , MemoryQuery = require('../queries/MemoryQuery')
  , noop = require('../util').noop
  ;

module.exports = {
  type: 'Model'

, events: {
    init: function (model) {
      // The following 2 private variables `_pathSubs` and _querySubs` remember
      // subscriptions. This memory is useful when the client may have been
      // disconnected from the server for quite some time and needs to re-send
      // it subscriptions upon re-connection in order for the server (1) to
      // figure out what data the client needs to re-sync its snapshot and (2)
      // to re-subscribe to the data on behalf of the client. The paths and
      // queries get cached in Model#subscribe.
      model._pathSubs = {} // path -> 1
      model._querySubs = {} // query hash -> MemoryQuery
    }

  , bundle: function (model, addToBundle) {
      var querySubs = model._querySubs
        , memoryQuery
        , queryJsons = [];
      for (var k in querySubs) {
        memoryQuery = querySubs[k];
        queryJsons.push(memoryQuery.toJSON());
      }
      addToBundle('_loadSubs', model._pathSubs, queryJsons);
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
          , collection = memory.get(ns);
        // If the doc is already in the model, don't add it
        if (collection && collection[doc.id]) {
          // But add a null transaction anyway, so that `txnApplier` doesn't
          // hang because it never sees `num`
          return model._addRemoteTxn(null, num);
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
        var hash = payload.channel
          , data = payload.data
          , ns   = data.ns
          , id   = data.id
          , ver  = data.ver
          , pathToDoc = ns + '.' + id
          , doc = model.get(pathToDoc);

        // Don't remove the doc if any other queries match the doc
        var querySubs = model._querySubs;
        for (var k in querySubs) {

          // If "rmDoc" was triggered by the same query, we expect it not to match the query, so ignore it
          if (hash.substring(3) === k) continue; // `substring` strips the leading "$q."

          var memoryQuery = querySubs[k];
          // If the doc belongs in an existing subscribed query's result set,
          // then don't remove it, but instead apply a "null" transaction to
          // make sure the transaction counter `num` is acknowledged, so other
          // remote transactions with a higher counter can be applied.
          if (memoryQuery.filterTest(doc, ns)) {
            return model._addRemoteTxn(null, num);
          }
        }

        var txn = transaction.create({
            ver: ver
          , id: null
          , method: 'del'
          , args: [pathToDoc]
        });
        model._addRemoteTxn(txn, num);
        model.emit('rmDoc', pathToDoc, doc);
      });
    }
  }

, proto: {
    // TODO Change DS?
    _loadSubs: function (pathSubs, querySubList) {
      this._pathSubs = pathSubs;
      for (var queryJson in querySubList) {
        var hash = QueryBuilder.hash(queryJson);
        querySubs[hash] = new MemoryQuery(queryJson);
      }
    }

    // subscribe(targets..., callback)
  , subscribe: function () {
      var pathSubs = this._pathSubs
        , querySubs = this._querySubs;

      this._compileTargets(arguments, {
        compileModelAliases: true
      , eachQueryTarget: function (queryJson, addToTargets, aliasPath) {
          var hash = QueryBuilder.hash(queryJson);
          if (! (hash in querySubs)) {
            querySubs[hash] = new MemoryQuery(queryJson);
            addToTargets(queryJson);
            var pointerListPath = '_$queries.' + hash + '._resultIds';
            this.refList(aliasPath, queryJson.from, pointerListPath);
          }
        }
      , eachPathTarget: function (path, addToTargets) {
          if (path in pathSubs) return;
          pathSubs[path] = 1;
          addToTargets(path); // TODO push unexpanded target or expanded path?
        }
      , done: function (targets, modelAliases, subscribeCb) {
          if (! targets.length) {
            return subscribeCb.apply(this, [null].concat(modelAliases));
          }
          var self = this;
          this._addSub(targets, function (err, data) {
            if (err) return subscribeCb(err);
            self._addData(data);
            self.emit('addSubData', data);
            subscribeCb.apply(this, [null].concat(modelAliases));
          });
        }
      });
    }

    // unsubscribe(targets..., callback)
  , unsubscribe: function () {
      var pathSubs = this._pathSubs
        , querySubs = this._querySubs;

      this._compileTargets(arguments, {
        compileModelAliases: false
      , eachQueryTarget: function (queryJson, addToTargets) {
          var hash = QueryBuilder.hash(queryJson);
          if (! (hash in querySubs)) return;
          delete querySubs[hash];
          addToTargets(queryJson);
        }
      , eachPathTarget: function (path, addToTargets) {
          if (! (path in pathSubs)) return;
          delete pathSubs[path];
          addToTargets(path);
        }
      , done: function (targets, unsubscribeCb) {
          if (! targets.length) return unsubscribeCb();
          this._removeSub(targets, unsubscribeCb);
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

  , _addSub: function (targets, cb) {
      if (! this.connected) return cb('disconnected');
      this.socket.emit('addSub', targets, cb);
    }

  , _removeSub: function (targets, cb) {
      if (! this.connected) return cb('disconnected');
      this.socket.emit('removeSub', targets, cb);
    }

  , _subs: function () {
      var subs = Object.keys(this._pathSubs)
        , querySubs = this._querySubs;
      for (var hash in querySubs) {
        subs.push(querySubs[hash].toJSON());
      }
      return subs;
    }
  }

, server: {
    _addSub: function (targets, cb) {
      var store = this.store;
      this._clientIdPromise.on( function (err, clientId) {
        if (err) return cb(err);
        // Subscribe while the model still only resides on the server.
        // The model is unsubscribed before sending to the browser.
        store.subscribe(clientId, targets, cb);
      });
    }

  , _removeSub: function (targets, cb) {
      var store = this.store;
      this._clientIdPromises.on( function (err, clientId) {
        if (err) return cb(err);
        store.unsubscribe(clientId, targets, cb);
      });
    }
  }
};
