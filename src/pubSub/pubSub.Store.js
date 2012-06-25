var finishAfter = require('../util/async').finishAfter
  , PubSub = require('./PubSub')
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
      socket.on('addSub', function (targets, cb) {
        store.subscribe(socket, targets, cb);
      });

      socket.on('removeSub', function (targets, cb) {
        store.unsubscribe(socket, targets, cb);
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
    subscribe: function (socket, targets, callback) {
      var data = null
        , finish = finishAfter(2, function (err) {
            callback(err, data);
          });

      // TODO This code does not feel right
      var pubSubTargets = []
        , queryMotifRegistry = this._queryMotifRegistry;
      for (var i = targets.length; i--; ) {
        var currTarget = targets[i];
        pubSubTargets[i] = (Array.isArray(currTarget))
                           // If we have a query tuple
                         ? queryMotifRegistry.queryJSON(currTarget)
                           // Else we have a path
                         : currTarget;
      }

      // This call to subscribe must come before the fetch, since a query is
      // created in subscribe that may be accessed during the fetch.
      this._pubSub.subscribe(socket.clientId, pubSubTargets, finish);
      this.fetch(socket, targets, function (err, _data) {
        data = _data;
        finish(err);
      });
    }

  , unsubscribe: function (socket, targets, callback) {
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
