var Promise = require('../util/Promise')
  , transaction = require('../transaction')
  , createMiddleware = require('../middleware')
  , noop = require('../util').noop
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

      //middleware.txn.add(middleware.beforeAccessControl);
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
      middleware.txn.add(function (req, res, next) {
        middleware.afterDb(req, res, next);
      });
      middleware.txn.add(publish);
      middleware.txn.add(authorAck);

      function accessController (req, res, next) {
        // Any operations authored by Store get a free pass
        if (req.clientId === store._clientId) return next();
        var txn = req.data;
        var contextName = transaction.getContext(txn);
        var context = store.context(contextName);
        context.guardWrite(req, res, next);
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
        // Clone so version of the txn that we ack is not incremented in
        // QueryHub; the clone is instead.
        txn = txn.slice();
        store.publish(path, 'txn', txn, {origDoc: origDoc});
        next();
      }

      function authorAck (req, res, next) {
        var txn = req.data;
        if (req.socket) { // Only generate txn serialization nums for requests originating from a browser model
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
        , socket: true
        };
        var res = {
          fail: function (err) {
            // Return errors to client, with the exception of duplicates, which
            // may need to be sent to the model again
            if (err !== 'duplicate') {
              // TODO Should allow different kinds of error types -- e.g., "txnErr"
              socket.emit('txnErr', err, transaction.getId(txn));
            }
          }
        , send: function (txn, num) {
            socket.emit('txnOk', txn, num);
          }
        };
        store.middleware.txn(req, res);
      });
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
        fail: callback || noop
      , send: function (txn) {
          callback && callback(null, txn);
        }
      };
      this.middleware.txn(req, res);
    }
  }
};
