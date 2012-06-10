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
      // its subscriptions upon re-connection in order for the server (1) to
      // figure out what data the client needs to re-sync its snapshot and (2)
      // to re-subscribe to the data on behalf of the client. The paths and
      // queries get cached in Model#subscribe.
      model._pathSubs  = {}; // path -> Boolean
      model._querySubs = {}; // Maps query hash -> Boolean
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
        var hash = payload.channel
          , data = payload.data
          , doc  = data.doc
          , id   = data.id
          , ns   = data.ns
          , ver  = data.ver;

        // Don't remove the doc if any other queries match the doc
        var querySubs = model._querySubs;
        for (var currHash in querySubs) {

          // If "rmDoc" was triggered by the same query, we expect it not to match the query, so ignore it
          if (hash.substring(3) === currHash) continue; // `substring` strips the leading "$q."

          var memoryQuery = model.locateQuery(currHash);
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
            });
        var oldDoc = model.get(pathToDoc);
        model._addRemoteTxn(txn, num);
        model.emit('rmDoc', pathToDoc, oldDoc);
      });
    }
  }

, proto: {
    _loadSubs: function (pathSubs, querySubList) {
      this._pathSubs = pathSubs;
      var querySubs = this._querySubs;
      for (var queryJson in querySubList) {
        var hash = QueryBuilder.hash(queryJson)
          , memoryQuery = new MemoryQuery(queryJson);
        this.registerQuery(memoryQuery, querySubs);
      }
    }

    // subscribe(targets..., callback)
  , subscribe: function () {
      var pathSubs = this._pathSubs
        , querySubs = this._querySubs
        , self = this;

      this._compileTargets(arguments, {
        eachQueryTarget: function (queryJson, targets) {
          var hash = QueryBuilder.hash(queryJson);
          if (! (hash in querySubs)) {
            self.registerQuery(new MemoryQuery(queryJson), querySubs);
            targets.push(queryJson);
          }
        }
      , eachPathTarget: function (path, targets) {
          if (path in pathSubs) return;
          pathSubs[path] = true;
          targets.push(path); // TODO push unexpanded target or expanded path?
        }
      , done: function (targets, modelScopes, subscribeCb) {
          if (! targets.length) {
            return subscribeCb.apply(this, [null].concat(modelScopes));
          }
          var self = this;
          this._addSub(targets, function (err, data) {
            if (err) return subscribeCb(err);
            self._addData(data);
            self.emit('addSubData', data);
            subscribeCb.apply(this, [null].concat(modelScopes));
          });
        }
      });
    }

    // unsubscribe(targets..., callback)
  , unsubscribe: function () {
      var pathSubs = this._pathSubs
        , querySubs = this._querySubs
        , self = this;

      this._compileTargets(arguments, {
        eachQueryTarget: function (queryJson, targets) {
          var hash = QueryBuilder.hash(queryJson);
          if (! (hash in querySubs)) return;
          self.unregisterQuery(hash, querySubs);
          targets.push(queryJson);
        }
      , eachPathTarget: function (path, targets) {
          if (! (path in pathSubs)) return;
          delete pathSubs[path];
          targets.push(path);
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
        subs.push(this.locateQuery(hash).toJSON());
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
