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

        , clientNum = {};

      var txnClock = store._txnClock = {
        unregister: function (clientId) {
          delete clientNum[clientId];
        }
      , register: function (clientId) {
          clientNum[clientId] = 1;
        }
      , nextTxnNum: function (clientId) {
          if (! (clientId in clientNum)) this.register(clientId);
          return clientNum[clientId]++;
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
          // Only generate txn serialization nums for requests originating from a browser model
          // TODO: Is this really correct? Might this be messing up tests in offline.mocha?

          // Prevent sending duplicate transactions by only sending new versions
          var ver = transaction.getVer(txn);
          if (ver > socket.__ver) {
            socket.__ver = ver;
            store.serialEmit(socket, 'txn', txn);
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

      var mode = store._mode
        , txnClock = store._txnClock;

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
      middleware.txn.add(serialEmitPrep);
      // middleware.add('txn', db); // could use db in middleware.fetch.add(db), too. The db file could just define different handlers per channel, so all logic for db is in one file
      middleware.txn.add(writeToDb);
      middleware.txn.add(publish);
      middleware.txn.add(authorAck);
      middleware.txn.add(function (req, res, next) {
        // Have to wrap middleware.afterDb because it is not defined when
        // middleware.txn.add is invoked
        middleware.afterDb(req, res, next);
      });

      function accessController (req, res, next) {
        // Any operations authored by Store get a free pass
        if (req.clientId === store._clientId) return next();
        var txn = req.data;
        var contextName = transaction.getContext(txn);
        var context = store.context(contextName);
        context.guardWrite(req, res, next);
      }

      // Make sure to send messages back to the user in an order that is
      // monotonic with the version number
      var versToPublish = [];
      var publishQueueByVer = {};
      store.serialEmit = serialEmit;
      store.serialCleanup = function (txn) {
        var ver = transaction.getVer(txn);
        publishQueueByVer[Math.floor(ver)].okToClear = true;
        tmp(versToPublish, publishQueueByVer, ver, noop, {
          afterEmit: function () {
            flush(versToPublish, publishQueueByVer, Math.floor(ver));
          }
        });
      };
      function serialEmitPrep (req, res, next) {
        var ver = req.newVer;
        // req.newVer is guaranteed to be received here monotonically
        versToPublish.push(ver);
        publishQueueByVer[ver] = [];
        next();
      };
      function tmp (versToPublish, publishQueueByVer, ver, emit, cbs) {
        var normVer = Math.floor(ver); // In case of fractional versions from addDoc and rmDoc
        var verIndex = versToPublish.indexOf(normVer);
        if (verIndex === 0) {
          emit();
          cbs && cbs.afterEmit && cbs.afterEmit();
        } else {
          if (verIndex === -1) {
            cbs.onVerNotFound(versToPublish, normVer);
          }
          var list = publishQueueByVer[normVer];
          var k = list.length;
          while (k--) {
            if (list[k] < ver) {
              list.splice(k + 1, 0, emit);
              break;
            }
          }
          if (k === -1) {
            list.unshift(emit);
          }
        }
      }
      function serialEmit (socket, messageType, payload) {
        var txn, ver, verIndex;

        switch (messageType) {
          case 'txn':
            txn = payload;
            ver = transaction.getVer(txn);
            tmp(versToPublish, publishQueueByVer, ver, emit, {
              onVerNotFound: function (versToPublish, normVer) {
                versToPublish.push(normVer);
              }
            });
            break;
          case 'addDoc':
          case 'rmDoc':
            var data = payload.data;
            txn = data.txn;
            ver = data.ver;
            tmp(versToPublish, publishQueueByVer, ver, emit, {
              onVerNotFound: function (versToPublish, normVer) {
                versToPublish.push(normVer);
              }
            });
            break;
          case 'txnOk':
            txn = payload;
            ver = transaction.getVer(txn);
            publishQueueByVer[ver].okToClear = true;

            tmp(versToPublish, publishQueueByVer, ver, emit, {
              afterEmit: function () {
                flush(versToPublish, publishQueueByVer, ver);
              }
            , onVerNotFound: function () {
                throw new Error('Unexpected index');
              }
            });
            break;
          default:
            throw new Error('Unexpected message type: ' + messageType);
        }
        function emit () {
          var num = store._txnClock.nextTxnNum(socket.clientId);
          socket.emit(messageType, payload, num);
        }
        emit.ver = ver;
      }
      function flush (versToPublish, publishQueueByVer, ver) {
        var buffered = publishQueueByVer[ver];
        if (! buffered.okToClear) return;
        var fn;
        while (fn = buffered.shift()) fn();
        delete publishQueueByVer[ver];
        versToPublish.shift();
        var nextVer = versToPublish[0];
        if (!nextVer) return;
        flush(versToPublish, publishQueueByVer, nextVer);
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
        res.send(txn);
        next();
      }
    }

  , socket: function (store, socket, clientId) {
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
        , send: function (txn) {
            store.serialEmit(socket, 'txnOk', txn);
            // socket.emit('txnOk', txn, num);
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
      var store = this;
      var res = {
        fail: callback || noop
      , send: function (txn) {
          store.serialCleanup(txn);
          callback && callback(null, txn);
        }
      };
      this.middleware.txn(req, res);
    }
  }
};
