var finishAfter = require('../util/async').finishAfter
  , PubSub = require('./PubSub')
  , createMiddleware = require('../middleware')
  ;

module.exports = {
  type: 'Store'

, events: {
    init: function (store, opts) {
      var pubSub = store._pubSub = new PubSub
        , clientSockets = store._clientSockets;

      // TODO Move this behind the channel-interface-query abstraction
      pubSub.on('noSubscribers', function (path) {
        // TODO liveQueries is deprecated
        delete liveQueries[path];
      });

      // Live Query Channels
      // These following 2 channels are for informing a client about
      // changes to their data set based on mutations that add/rm docs
      // to/from the data set enclosed by the live queries the client
      // subscribes to.
      ['addDoc', 'rmDoc'].forEach( function (messageType) {
        pubSub.on(messageType, function (clientId, params) {
          var num = store._txnClock.nextTxnNum(clientId)
            , socket = store._clientSockets[clientId];
          if (!socket) return;
          return socket.emit(messageType, params, num);
        });
      });
    }

  , socket: function (store, socket, clientId) {
      // Setup subscription callbacks
      socket.on('subscribe', function (targets, contextName, cb) {
        var req = {
          clientId: socket.clientId
        , session: socket.session
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

      socket.on('unsubscribe', function (targets, context, cb) {
        store.unsubscribe(socket, targets, context, cb);
      });
    }

  , middleware: function (store, middleware) {
      middleware.subscribe = createMiddleware()

      // Access Control
      middleware.subscribe.add(function (req, res, next) {
        var targets = req.targets
          , numTargets = targets.length
          , context = req.context;
        var finish = finishAfter(numTargets, next);
        for (var i = 0; i < numTargets; i++) {
          var target = targets[i];
          var _req = {
            target: target
          , clientId: req.clientId
          , session: req.session
          , context: context
          };
          var _res = {
            fail: function (err) { res.fail(err); }
          , send: function (data) {
              throw new Error('This res.send should never get called');
            }
          };
          var mware = ('string' === typeof target)
                    ? context.guardReadPath
                    : context.guardQuery;
          mware(_req, _res, finish);
        }
      });

      // Subscribe
      middleware.subscribe.add(function (req, res, next) {
        var targets = req.targets
          , pubSubTargets = []
          , queryMotifRegistry = store._queryMotifRegistry;
        for (var i = 0, l = targets.length; i < l; i++) {
          var target = targets[i];
          pubSubTargets.push(
            (typeof target === 'string')
            ? target
            : queryMotifRegistry.queryJSON(target)
          );
        }
        var clientId = req.clientId;
        // This call to subscribe must come before the fetch, since a query is
        // created in subscribe that may be accessed during the fetch.
        store._pubSub.subscribe(clientId, pubSubTargets, function (err) {
          if (err) return res.fail(err);
          next();
        });
      });

      // Fetch
      middleware.subscribe.add(function (req, res, next) {
        var _req = {
          targets: req.targets
        , clientId: req.clientId
        , session: req.session
        , context: req.context
        };
        var _res = {
          fail: function (err) { res.fail(err); }
        , send: function (data) { res.send(data); }
        };
        middleware.fetch(_req, _res, next);
      });
    }
  }

, proto: {
    /**
     * Fetch the set of data represented by `targets` and subscribe to future
     * changes to this set of data.
     *
     * @param {Socket} socket representing the subscriber
     * @param {String|Array} targets (i.e., paths, path patterns, or query
     * tuples) to subscribe to
     * @param {Function} callback(err, data)
     * @api protected
     */
    subscribe: function (socket, targets, context, callback) {
      var i, currTarget;


      // TODO This code does not feel right
      var pubSubTargets = []
        , queryMotifRegistry = this._queryMotifRegistry;
      for (i = targets.length; i--; ) {
        currTarget = targets[i];
        pubSubTargets[i] = (Array.isArray(currTarget))
                           // If we have a query tuple
                         ? queryMotifRegistry.queryJSON(currTarget)
                           // Else we have a path
                         : currTarget;
      }

      var data = null;
      var finish = finishAfter(2, function (err) {
        callback(err, data);
      });
      // This call to subscribe must come before the fetch, since a query is
      // created in subscribe that may be accessed during the fetch.
      this._pubSub.subscribe(socket.clientId, pubSubTargets, finish);
      this.fetch(socket, targets, this.scopedContext, function (err, _data) {
        data = _data;
        finish(err);
      });
    }

  , unsubscribe: function (socket, targets, context, callback) {
      this._pubSub.unsubscribe(socket.clientId, targets, callback);
    }

  , publish: function (path, type, data, meta) {
      var msg = {
        type: type
      , params: {
          channel: path
        , data: data
        }
      };
      this._pubSub.publish(msg, meta);
    }
  }
};
