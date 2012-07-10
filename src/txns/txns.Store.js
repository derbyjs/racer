var Promise = require('../util/Promise')
  , transaction = require('../transaction')
  , createMiddleware = require('../middleware')
  ;

module.exports = {
  type: 'Store'

, events: {
    init: function (store) {
      var clientSockets = store._clientSockets
        , localModels = store._localModels

        , nextTxnNum = {};

      var txnClock = store._txnClock = {
        unregister: function (clientId) {
          delete nextTxnNum[clientId];
        }
      , register: function (clientId) {
          nextTxnNum[clientId] = 1;
        }
      , nextTxnNum: function (clientId) {
          if (! (clientId in nextTxnNum)) this.register(clientId);
          return nextTxnNum[clientId]++;
        }
      };

      // clientId -> {timeout, buffer}
      store._txnBuffers = {};

      store._pubSub.on('txn', function (clientId, txn) {
        // Don't send transactions back to the model that created them.
        // On the server, the model directly handles the store._commit callback.
        // Over Socket.io, a 'txnOk' message is sent instead.
        if (clientId === transaction.getClientId(txn)) return;
        // For models only present on the server, process the transaction
        // directly in the model
        var model = localModels[clientId]
        if (model) return model._onTxn(txn);

        // Otherwise, send the transaction over Socket.io
        var socket = clientSockets[clientId];
        if (socket) {
          // Prevent sending duplicate transactions by only sending new versions
          var ver = transaction.getVer(txn);
          if (ver > socket.__ver) {
            socket.__ver = ver;
            var num = txnClock.nextTxnNum(clientId);
            socket.emit('txn', txn, num);
          }
          return;
        }

        // However, the client may not be connected, which is true in the
        // following scenarios:
        //
        // 1. During initial Model#bundle and socket 'connection' event
        // 2. If a browser loses connection
        var buffer = store._txnBuffer(clientId);
        if (buffer) buffer.push(txn);
      });
    }

  , middleware: function (store, middleware) {
      middleware.txn = createMiddleware();

      var mode = store._mode;
      if (mode.startIdVerifier) {
        middleware.txn.add(mode.startIdVerifier);
      }

      middleware.txn.add(accessController);
      // middleware.add('txn', validator);
      if (mode.detectConflict) {
        middleware.txn.add(mode.detectConflict);
      }
      // middleware.txn.add(handleConflict);
      // middleware.txn.add(journal)
      if (mode.addToJournal) {
        middleware.txn.add(mode.addToJournal);
      }
      middleware.txn.add(mode.incrVer);
      // middleware.add('txn', db); // could use db in middleware.fetch.add(db), too. The db file could just define different handlers per channel, so all logic for db is in one file
      middleware.txn.add(writeToDb);
      middleware.txn.add(publish);
      middleware.txn.add(authorAck);

      function accessController (req, res, next) {
        // Any operations authored by Store get a free pass
        if (req.clientId === store._clientId) return next();

        var txn = req.data;
        var session = req.session;
        var allowed = store._applyGuards(txn, session);
        return allowed ? next() : res.fail('Unauthorized');
      }

      // TODO Optimize function defns
      function writeToDb (req, res, next) {
        var txn = req.data
          , dbArgs = transaction.copyArgs(txn)
          , method = transaction.getMethod(txn)
          , ver = req.newVer;
        dbArgs.push(ver);
        store._sendToDb(method, dbArgs, function (err, origDoc) {
          if (err)
            return res.fail(err, txn); // TODO Why pass back txn?
          req.origDoc = origDoc;
          next();
        });
      }
      function publish (req, res, next) {
        var txn = req.data
          , origDoc = req.origDoc
          , path = transaction.getPath(txn);
        store.publish(path, 'txn', txn, {origDoc: origDoc});
        next();
      }

      function authorAck (req, res, next) {
        var txn = req.data;
        if (req.session) { // Only generate txn serialization nums for requests originating from a browser model
          var num = store._txnClock.nextTxnNum(req.clientId);
          res.send(txn, num);
        } else {
          res.send(txn);
        }
        next();
      }
    }

  , socket: function (store, socket, clientId) {
      var txnClock = store._txnClock;
      // This is used to prevent emitting duplicate transactions
      socket.__ver = 0;

      socket.on('txn', function (txn, clientStartId) {
        var req = {
          data: txn
        , startId: clientStartId
        , clientId: socket.clientId
        , session: socket.session
        };
        var res = {
          fail: function (err) {
            // Return errors to client, with the exception of duplicates, which
            // may need to be sent to the model again
            if (err !== 'duplicate') {
              // TODO Should allow different kinds of error types -- e.g., "txnErr"
              socket.emit('fatalErr', err);
            }
          }
        , send: function (txn, num) {
            socket.emit('txnOk', txn, num);
          }
        };
        store.middleware.txn(req, res);
      });

      // TODO Move into reconnect mixin and expose events?
      socket.on('disconnect', function () {
        delete store._clientSockets[clientId];
        // Start buffering transactions on behalf of this disconnected client.
        // Buffering occurs for up to 3 seconds.
        store._startTxnBuffer(clientId, 3000);
      });

      // Check to see if this socket connection is
      // 1. The first connection after the server ships the bundled model to the browser.
      // 2. A connection that occurs shortly after an aberrant disconnect
      if (store._txnBuffer(clientId)) {
        // If so, the store has been buffering any transactions meant to be
        // received by the (disconnected) browser model because of model subscriptions.

        // So stop buffering the transactions
        store._cancelTxnBufferExpiry(clientId);
        // And send the buffered transactions to the browser
        store._flushTxnBuffer(clientId, socket);
      } else {
        // Otherwise, the server store has completely forgotten about this
        // client because it has been disconnected too long. In this case, the
        // store should
        // 1. Ask the browser model what it is subscribed to, so we can re-establish subscriptions
        // 2. Send the browser model enough data to bring it up to speed with
        //    the current data snapshot according to the server. When the store uses a journal, then it can send the browser a set of missing transactions. When the store does not use a journal, then it sends the browser a new snapshot of what the browser is interested in; the browser can then set itself to the new snapshot and diff it against its stale snapshot to reply the diff to the DOM, which reflects the stale state.
        socket.emit('resyncWithStore', function (subs, clientVer, clientStartId) {
          store._onSnapshotRequest(clientVer, clientStartId, clientId, socket, subs, 'shouldSubscribe');
        });
      }
    }
  }

, proto: {
    _commit: function (txn, callback) {
      var req = {
        data: txn
      , clientId: this._clientId
      };
      if (this._mode._startId) {
        req.startId = this._mode._startId;
      }
      var res = {
        fail: callback
      , send: function () {
          var args = Array.prototype.slice.call(arguments, 0);
          callback.apply(null, [null].concat(args));
        }
      };
      this.middleware.txn(req, res);
    }
  , _startTxnBuffer: function (clientId, timeoutAfter) {
      var txnBuffers = this._txnBuffers;
      if (clientId in txnBuffers) {
        console.warn('Already buffering transactions for client ' + clientId);
        console.trace();
        return;
      }
      var buffer = []
        , self = this;
      txnBuffers[clientId] = {
        buffer: buffer
      , timeout: setTimeout(function () {
          self.unsubscribe(clientId);
          self._txnClock.unregister(clientId);
          delete txnBuffers[clientId];
        }, timeoutAfter || 3000)
      };
      return buffer;
    }

  , _txnBuffer: function (clientId) {
      var txnBuffers = this._txnBuffers
        , meta = txnBuffers[clientId];
      return meta && meta.buffer;
    }

  , _cancelTxnBufferExpiry: function (clientId) {
      clearTimeout(this._txnBuffers[clientId].timeout);
    }

  , _flushTxnBuffer: function (clientId, socket) {
      var txnBuffers = this._txnBuffers
        , txns = txnBuffers[clientId].buffer;
      socket.emit('snapshotUpdate:newTxns', txns);
      delete txnBuffers[clientId];
    }
  }
};
