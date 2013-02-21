var Memory = require('../Memory')
  , Promise = require('../util/Promise')
  , Serializer = require('../Serializer')
  , transaction = require('../transaction')
  , pathUtils = require('../path')
  , isPrivate = pathUtils.isPrivate
  , isPathToDoc = pathUtils.isPathToDoc
  , subPathToDoc = pathUtils.subPathToDoc
  , lookup = pathUtils.lookup
  , specCreate = require('../util/speculative').create
  , createMiddleware = require('../middleware')
  , arrayMutator = null

    // Timeout in milliseconds after which sent transactions will be resent
  , SEND_TIMEOUT = 20000

    // Interval in milliseconds to check timeouts for queued transactions
  , RESEND_INTERVAL = 20000
  ;

module.exports = {
  type: 'Model'

, static: {
    SEND_TIMEOUT: SEND_TIMEOUT
  , RESEND_INTERVAL: RESEND_INTERVAL
  }

, events: {
    mixin: function (Model) {
      arrayMutator = Model.arrayMutator;
    }

  , init: function (model) {
      // Add a promise that is checked at bundle time to make sure all
      // transactions have been committed on the server before a model gets
      // serialized
      var bundlePromises = model._bundlePromises;
      if (bundlePromises) {
        var promise = model._txnsPromise = new Promise();
        bundlePromises.push(promise);
      }

      var specCache = model._specCache = {
        invalidate: function () {
          delete this.data;
          delete this.lastTxnId;
        }
      };

      model._count = {txn: 0};

      model._txns = {}; // transaction id -> transaction
      model._txnQueue = []; // [transactionIds...]

      model._removeTxn = function (txnId) {
        delete model._txns[txnId];
        var txnQueue = model._txnQueue;
        var i = txnQueue.indexOf(txnId);
        if (~i) {
          model._txnQueue.splice(i, 1);
          specCache.invalidate();
          model.emit('rmTxn', txnId, txnQueue.length);
        }
      };

      // TODO Add client-side filtering for incoming data on
      // no-longer-subscribed-to channels. This alleviates race condition of
      // receiving a messages on a channel the client just subscribed to

      var memory = model._memory;
      model._onTxn = function (txn) {
        if (!txn) return;

        // Copy meta properties onto this txn if it matches one in the queue
        var txnQ = model._txns[transaction.getId(txn)];
        if (txnQ) {
          txn.callback = txnQ.callback;
          txn.emitted = txnQ.emitted;
        }

        var isLocal = 'callback' in txn
          , ver = transaction.getVer(txn);
        if (ver > memory.version || ver === -1) {
          model._applyTxn(txn, isLocal);
        }
      };
    }

  , middleware: function (_model, middleware) {
      middleware.txn = createMiddleware();

      middleware.txn.add(normalizeTxn);
      // TODO middleware.txn.add(typecast);
      // TODO middleware.txn.add(validate);
      middleware.txn.add(logTxn);
      // Evaluate the transaction, which is now on the queue
      middleware.txn.add(evalTxn);
      // Add insert index as txn metadata
      middleware.txn.add(addInsertMetadata);
      // Commit needs to happen before emit, since emissions might create other
      // transactions as a side effect
      middleware.txn.add(commitTxn);
      // Send the transaction ...
      // - ... over Socket.IO if a browser Model
      // - ... to the store if a server Model
      middleware.txn.add(emitTxn);

      function normalizeTxn (req, res, next) {
        var txn = req.data
          , method = transaction.getMethod(txn)
          , args = transaction.getArgs(txn)
          , model = req.model;

        // Refs may mutate the args in its 'beforeTxn' handler
        model.emit('beforeTxn', method, args);
        var path = args[0];
        if (~ path.indexOf('.undefined')) {
          return console.warn('You were about to set on a path including undefined: ' + path);
        }
        if (typeof path === 'undefined') {
          return console.warn('You were about to set on undefined path');
        }
        txn.isPrivate = isPrivate(path);

        // args = transaction.getArgs(txn)
        txn.emitted = txn.emitted || args.cancelEmit;

        // Add remove index as txn metadata. Null if transaction does nothing
        if (method === 'pop') {
          var arr = model.get(path);
          txn.push(arr ? arr.length - 1 : null);
        } else if (method === 'unshift') {
          txn.push(model.get(path) ? 0 : null);
        }
        return next();
      }

      function logTxn (req, res, next) {
        var txn = req.data
          , model = req.model
          , id = transaction.getId(txn);
        model._txns[id] = txn;
        model._txnQueue.push(id);
        return next();
      }

      function evalTxn (req, res, next) {
        res.out = req.model._specModel().$out;
        return next();
      }

      function addInsertMetadata (req, res, next) {
        var txn = req.data
          , args = transaction.getArgs(txn)
          , method = transaction.getMethod(txn)
          ;
        if (method === 'push') {
          var out = res.out
            , k = out - args.length + 1;
          transaction.setMeta(k);
          txn.push(k);
        }
        return next();
      }

      function commitTxn (req, res, next) {
        var txn = req.data;
        req.model._commit(txn);
        return next();
      }

      function emitTxn (req, res, next) {
        var txn = req.data;
        if (txn.emitted) return res.out;

        var method = transaction.getMethod(txn)
            // Clone the args, so that they can be modified before being
            // emitted without affecting the txn args
          , args = transaction.copyArgs(txn)
          , model = req.model;
        model.emit(method, args, res.out, true, model._pass);
        txn.emitted = true;
        // return next();
        return res.out;
      }
    }

  , bundle: function (model) {
      model._txnsPromise.on( function (err) {
        if (err) throw err;
        var clientId = model._clientId
          , store = model.store;
        if (store) {
          // In case we already unregistered local model
          // TODO Investigate why this is the case
          store._unregisterLocalModel(clientId);
        } else {
          console.warn('ALREADY UNREGISTERED SERVER MODEL');
          console.trace();
        }

        // Start buffering subsequently received transactions. They will be
        // sent to the browser upon browser connection. This also occurs on 'disconnect'
        store._startTxnBuffer(clientId);
      });

      // Get the speculative model, which will apply any pending private path
      // transactions that may get stuck in the first position of the queue
      model._specModel();

      // If we have no pending transactions...
      if (! model._txnQueue.length) {
        return model._txnsPromise.resolve();
      }

      // Else...
      // Wait for all pending transactions to complete before returning
      // TODO This code is really confusing. Refactor
      if (! model.__removeTxn__) model.__removeTxn__ = model._removeTxn;
      model._removeTxn = function (txnId) {
        model.__removeTxn__(txnId);
        var len = model._txnQueue.length;
        model._specModel();
        if (len) return;

        process.nextTick( function () {
          model._txnsPromise.resolve();
        });
      };
    }

  , socket: function (model, socket) {
      var memory    = model._memory
        , removeTxn = model._removeTxn
        , onTxn     = model._onTxn

      // The startId is the ID of the last Journal restart. This is sent along with
      // each versioned message from the Model so that the Store can map the model's
      // version number to the version number of the Journal in case of a failure

      // These events are triggered by the 'resyncWithStore' event in the
      // reconnect mixin and the
      // txnApplier timeout below. A request is made to the server to fetch the
      // most recent snapshot, which is returned to the browser in one of many
      // forms on a channel prefixed with "snapshotUpdate:*"
      socket.on('snapshotUpdate:replace', function (data, num) {
        // TODO Over-ride and replay diff as events?

        // TODO: OMG NASTY HACK, but this prevents a number of issues that can
        // come up if rendering in strange states
        if (typeof DERBY !== 'undefined') DERBY.app.dom._preventUpdates = true;

        var oldTxnQueue = model._txnQueue
          , oldTxns = model._txns
          , txnQueue = model._txnQueue = []
          , txns = model._txns = {};

        // Reset the number used to keep track of pending transactions
        txnApplier.clearPending();
        if (num != null) txnApplier.setIndex(num + 1);

        model._specCache.invalidate();
        memory.eraseNonPrivate();
        var maxVersion = 0
          , targetData = data.data
        for (var i = targetData.length; i--;) {
          maxVersion = Math.max(targetData[i][2], maxVersion);
        }
        memory.version = maxVersion;

        // TODO memory.flush?
        model._addData(data);

        var txnId, txn
        for (var i = 0, l = oldTxnQueue.length; i < l; i++) {
          txnId = oldTxnQueue[i];
          txn = oldTxns[txnId];
          transaction.setVer(txn, maxVersion);
          txns[txnId] = txn;
          txnQueue.push(txnId);
          commit(txn);
        }

        if (typeof DERBY !== 'undefined') DERBY.app.dom._preventUpdates = false;

        model.emit('reInit');
      });

      socket.on('snapshotUpdate:newTxns', function (newTxns, num) {
        // Apply any missed transactions first
        for (var i = 0, l = newTxns.length; i < l; i++) {
          onTxn( newTxns[i] );
        }

        // Reset the number used to keep track of pending transactions
        txnApplier.clearPending();
        if (typeof num !== 'undefined') txnApplier.setIndex(num + 1);

        // Resend all transactions in the queue
        var txns = model._txns
          , txnQueue = model._txnQueue
        for (var i = 0, l = txnQueue.length; i < l; i++) {
          var id = txnQueue[i];
          // TODO In access control tests, same mutation sent twice as 2
          // different txns
          commit(txns[id]);
        }
      });

      var txnApplier = new Serializer({
        withEach: onTxn

        // This timeout is for scenarios when a service that the server proxies
        // to fails. This is for remote transactions.
      , onTimeout: function () {
          // TODO Make sure to set up the timeout again if we are disconnected
          if (! model.connected) return;
          // TODO Don't do this if we are also responding to a resyncWithStore
          socket.emit('fetch:snapshot', memory.version + 1, model._startId, model._subs());
        }
      });

      function resend () {
        var now = +new Date;
        // Evaluate to clear out private transactions at the beginning of the
        // queue
        model._specModel();
        var txns = model._txns
          , txnQueue = model._txnQueue
        for (var i = 0, l = txnQueue.length; i < l; i++) {
          var id = txnQueue[i]
            , txn = txns[id];
          if (! txn || txn.timeout > now) return;
          commit(txn);
        }
      }

      // Set an interval to check for transactions that have been in the queue
      // for too long and resend them
      var resendInterval = null;
      function setupResendInterval () {
        if (!resendInterval) resendInterval = setInterval(resend, RESEND_INTERVAL);
      }

      function teardownResendInterval () {
        if (resendInterval) clearInterval(resendInterval);
        resendInterval = null;
        if (model.connected) {
          setupResendInterval();
        } else {
          model.once('connect', setupResendInterval);
        }
      }

      // Stop resending transactions until reconnect
      // TODO Stop asking for missed remote transactions until reconnect
      socket.on('disconnect', teardownResendInterval);
      teardownResendInterval();

      model._addRemoteTxn = addRemoteTxn;
      function addRemoteTxn (txn, num) {
        if (typeof num !== 'undefined') {
          txnApplier.add(txn, num);
        } else {
          onTxn(txn);
        }
      }

      socket.on('txn', addRemoteTxn);

      // The model receives 'txnOk' from the server/store after the
      // server/store applies a transaction that originated from this model successfully
      socket.on('txnOk', function (rcvTxn, num) {
        var txnId = transaction.getId(rcvTxn)
          , txn = model._txns[txnId];
        if (!txn) return;
        var ver = transaction.getVer(rcvTxn);
        transaction.setVer(txn, ver);
        addRemoteTxn(txn, num);
      });

      // The model receives 'txnErr' from the server/store after the
      // server/store attempts to apply this transaction but fails
      socket.on('txnErr', function (err, txnId) {
        var txn = model._txns[txnId]
          , callback = txn && txn.callback;
        removeTxn(txnId);
        if (callback) {
          var callbackArgs = (transaction.isCompound(txn))
                           ? transaction.ops(txn)
                           : transaction.copyArgs(txn);
          callbackArgs.unshift(err);
          callback.apply(null, callbackArgs);
        }
      });

      model._commit = commit;
      function commit (txn) {
        if (txn.isPrivate) return;
        txn.timeout = +new Date + SEND_TIMEOUT;

        // Don't queue this up in socket.io's message buffer. Instead, we
        // explicitly send over an txns in this_txnQueue during reconnect synchronization
        if (! model.connected) return;

        socket.emit('txn', txn, model._startId);
      }
    }
  }

, server: {
    _commit: function (txn) {
      if (txn.isPrivate) return;
      var self = this
        , req = {
            data: txn
          , ignoreStartId: true
          , clientId: this._clientId
          , session: this.session
          }
        , res = {
            fail: function (err, txn) {
              self._removeTxn(transaction.getId(txn));
              txn.callback(err, txn);
            }
          , send: function (txn) {
              self._onTxn(txn);
              self.store.serialCleanup(txn);
            }
          };
      this.store.middleware.txn(req, res);
    }
  }

, proto: {
    // The value of this._force is checked in this._addOpAsTxn. It can be used
    // to create a transaction without conflict detection, such as
    // model.force().set
    force: function () {
      return Object.create(this, {_force: {value: true}});
    }
  , _commit: function () {}
  , _asyncCommit: function (txn, cb) {
      if (! this.connected) return cb('disconnected');
      txn.callback = cb;
      var id = transaction.getId(txn);
      this._txns[id] = txn;
      this._commit(txn);
    }

  , _nextTxnId: function () {
      return this._clientId + '.' + this._count.txn++;
    }

  , _queueTxn: function (txn, cb) {
      txn.callback = cb;
      var id = transaction.getId(txn);
      this._txns[id] = txn;
      this._txnQueue.push(id);
    }

  , _getVersion: function () {
      return this._force ? null : this._memory.version;
    }

  , _opToTxn: function (method, args, cb) {
      var ver = this._getVersion()
        , id = this._nextTxnId()
        , txn = transaction.create({
            ver: ver
          , id: id
          , method: method
          , args: args})
        ;
      txn.callback = cb;
      return txn;
    }

  , _sendToMiddleware: function (method, args, cb) {
      var txn = this._opToTxn(method, args, cb)
        , req = {
            data: txn
            // Pass in model, just in case scoped model where we need to access
            // model._pass
          , model: this
          }
        , res = {
            fail: function (err) { throw err; }
          , send: function () { console.log('TODO'); }
          }
        ;
      txn.emitted = this._silent;
      return this.middleware.txn(req, res);
    }

  , _applyTxn: function (txn, isLocal) {
      var txnId = transaction.getId(txn);
      if (txnId) this._removeTxn(txnId);
      // Invalidate cache, since we're about to update this._memory._data
      // beneath the spec model
      this._specCache.invalidate();
      var data = this._memory._data
        , doEmit = !txn.emitted
          // TODO Do we need Math.floor anymore?
        , ver = Math.floor(transaction.getVer(txn))
        , isCompound = transaction.isCompound(txn)
        , out
        ;
      if (isCompound) {
        var ops = transaction.ops(txn);
        for (var i = 0, l = ops.length; i < l; i++) {
          var op = ops[i];
          this._applyMutation(transaction.op, op, ver, data, doEmit, isLocal);
        }
      } else {
        // This commented out logic is incorrect. It is entirely valid to write to a
        // property of a doc that doesn't exist yet in Racer's current API. This
        // breaks example code and might not make sense with certain view bindings:

        // For transactions on a document attribute, only apply it if the doc
        // exists in our world. Otherwise, we are likely in a situation where
        // we received a transaciton for something that we were just
        // subscribed to but no longer are subscribed to. In this case, we
        // would not want this transaction to play.
        // Note: this.allowWritesOnAbsentDoc is for testing
        // if (! this.allowWritesOnAbsentDoc && docIsntPresent(this, txn, data)) {
        //   if (ver !== null) {
        //     this._memory.setVersion(ver);
        //   }
        //   return;
        // }
        out = this._applyMutation(transaction, txn, ver, data, doEmit, isLocal);
      }

      var callback = txn.callback;
      if (callback) {
        if (isCompound) {
          callback.apply(null, [null].concat(transaction.ops(txn)));
        } else {
          callback.apply(null, [null].concat(transaction.getArgs(txn), out));
        }
      }
      return out;
    }

    // `extractor` is either `transaction` or `transaction.op`
  , _applyMutation: function (extractor, txn, ver, data, doEmit, isLocal) {
      var out = extractor.applyTxn(txn, data, this._memory, ver);
      if (doEmit) {
        var patch = txn.patch;
        if (patch) {
          for (var i = 0, l = patch.length; i < l; i++) {
            var op = patch[i]
              , method = op.method
              , args = op.args
              ;
            this.emit(method, args, null, isLocal, this._pass);
          }
        } else {
          var method = transaction.getMethod(txn)
            , args = transaction.getArgs(txn);
          this.emit(method, args, out, isLocal, this._pass);
        }
        txn.emitted = true;
      }
      return out;
    }

  , _specModel: function () {
      var txns = this._txns
        , txnQueue = this._txnQueue
        , txn, out, data
      while ((txn = txns[txnQueue[0]]) && txn.isPrivate) {
        out = this._applyTxn(txn, true);
      }

      var len = txnQueue.length;
      if (! len) {
        data = this._memory._data;
        data.$out = out;
        return data;
      }

      var cache = this._specCache
        , lastTxnId = cache.lastTxnId
        , replayFrom
        ;
      if (lastTxnId) {
        if (cache.lastTxnId === txnQueue[len - 1]) return cache.data;
        data = cache.data;
        replayFrom = 1 + txnQueue.indexOf(cache.lastTxnId);
      } else {
        replayFrom = 0;
      }

      if (! data) {
        // Generate a specualtive model
        data = cache.data = specCreate(this._memory._data);
      }

      var i = replayFrom;
      while (i < len) {
        // Apply each pending operation to the speculative model
        var txn = txns[txnQueue[i++]];
        if (transaction.isCompound(txn)) {
          var ops = transaction.ops(txn);
          for (var k = 0, kk = ops.length; k < kk; k++) {
            this._applyMutation(transaction.op, ops[k], null, data);
          }
        } else {
          // This commented out logic is incorrect. See comment above

          // Note: this.allowWritesOnAbsentDoc is for testing
          // if (! this.allowWritesOnAbsentDoc && docIsntPresent(this, txn, data)) {
          //   continue;
          // }
          out = this._applyMutation(transaction, txn, null, data);
        }
      }

      cache.data = data;
      cache.lastTxnId = transaction.getId(txn);

      data.$out = out;

      return data;
    }
  }
};

// function docIsntPresent (model, txn, data) {
//   var path = transaction.getPath(txn);
//   if (! isPrivate(path) && ! isPathToDoc(path)) {
//     if (path.indexOf('.') === -1) {
//       return false; // Then this is a namespace collection
//     }
//     var pathToDoc = subPathToDoc(path);
//     data || (data = model._memory._data);
//     if (! lookup(pathToDoc, data.world)) {
//       return true;
//     }
//   }
//   return false;
// }
