var finishAfter = require('../util/async').finishAfter
  , PubSub = require('./PubSub')
  ;

module.exports = {
  type: 'Store'

, events: {
    init: function (store, opts) {
      var pubSub = store._pubSub = new PubSub
        , clientSockets = store._clientSockets
        , self = this;

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
        pubSub.on(messageType, function (clientId, data) {
          var num = self._txnClock.nextTxnNum(clientId)
            , socket = self._clientSockets[clientId];
          if (!socket) return;
          return socket.emit(messageType, data);
        });
      });
    }

  , socket: function (store, socket, clientId) {
      // Setup subscription callbacks
      socket.on('addSub', function (targets, cb) {
        store.subscribe(clientId, targets, cb);
      });

      socket.on('removeSub', function (targets, cb) {
        store.unsubscribe(clientId, targets, cb);
      });
    }
  }

, proto: {
    // Fetch the set of data represented by `targets` and subscribe to future
    // changes to this set of data.
    // @param {String} clientId representing the subscriber
    // @param {[String|Query]} targets (i.e., paths, or queries) to subscribe to
    // @param {Function} callback(err, data)
    subscribe: function (clientId, targets, cb) {
      var data = null
        , finish = finishAfter(2, function (err) {
            cb(err, data);
          });
      // This call to subscribe must come before the fetch, since a query is
      // created in subscribe that may be accessed during the fetch.
      this._pubSub.subscribe(clientId, targets, finish);
      this.fetch(clientId, targets, function (err, _data) {
        data = _data;
        finish(err);
      });
    }

  , unsubscribe: function (clientId, targets, cb) {
      this._pubSub.unsubscribe(clientId, targets, cb);
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
