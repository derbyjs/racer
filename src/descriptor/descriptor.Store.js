var Taxonomy = require('./Taxonomy')
  , normArgs = require('./util').normArgs
  , finishAfter = require('../util/async').finishAfter
  ;

module.exports = {
  type: 'Store'

, decorate: function (Store) {
    Store.prototype.descriptors = new Taxonomy;
    Store.dataDescriptor = function (conf) {
      var types = Store.prototype.descriptors
        , typeName = conf.name
        , type = types.type(typeName);
      if (type) return type;
      return types.type(typeName, conf);
    };
  }
, events: {
    middleware: function (store, middleware, createMiddleware) {
      var mode = store._mode;
      middleware.snapshot = createMiddleware()
      if (mode.startIdVerifier) {
        middleware.snapshot.add(mode.startIdVerifier);
      }
      middleware.snapshot.add( function (req, res, next) {
        var clientId = req.clientId;
        if (req.shouldSubscribe) {
          store._pubSub.subscribe(clientId, req.subs);
        }
        mode.snapshotSince({
          ver: req.ver
        , clientId: clientId
        , subs: req.subs
        , session: req.session
        , context: req.context
        }, function (err, payload) {
          if (err) return res.fail(err);
          var data = payload.data
            , txns = payload.txns
            , num = store._txnClock.nextTxnNum(clientId);
          if (data) {
            res.send('snapshotUpdate:replace', data, num);
          } else if (txns) {
            var len;
            if (len = txns.length) {
              socket.__ver = transaction.getVer(txns[len-1]);
            }
            res.send('snapshotUpdate:newTxns', txns, num);
          }
          next();
        });
      });

      middleware.fetch = createMiddleware()
      middleware.fetch.add(function (req, res, next) {
        var targets = req.targets
          , numTargets = targets.length
          , data = []
          , finish = finishAfter(numTargets, function (err) {
              if (err) return next(err);
              var out = {data: data};
              store.emit('fetch', out, req.clientId, targets);
              if (timesSendCalled === numTargets) {
                res.send(out);
              }
              next();
            })
          , session = req.session
          , timesSendCalled = 0
          ;
        for (var i = 0, l = numTargets; i < l; i++) {
          var target = targets[i]
            , _req = {
                target: target
              , clientId: req.clientId
              , session: req.session
              , context: req.context
              }
            , _res = {
                fail: function (err) {
                  res.fail(err);
                }
              , send: function (dataTriplets) {
                  timesSendCalled++;
                  data = data.concat(dataTriplets);
                }
              }
            , type = store.descriptors.typeOf(target)
            , mware = middleware['fetch' + type.name];

          mware(_req, _res, finish);
        }
      });
    }

  , socket: function (store, socket, clientId) {
      socket.on('fetch', function (targets, contextName, cb) {
        var req = {
          targets: targets
        , clientId: socket.clientId
        , session: socket.session
        , context: store.context(contextName)
        };
        var res = {
          fail: cb
        , send: function (data) {
            // For OT
            // Note that `data` may be mutated by ot or other plugins
            store.emit('fetch', data, clientId, targets);

            cb(null, data);
          }
        };
        store.middleware.fetch(req, res);
      });

      socket.on('fetch:snapshot', function (ver, clientStartId, subs) {
        store._onSnapshotRequest(ver, clientStartId, clientId, socket, subs);
      });
    }
  }
, proto: {
    fetch: function (/* descriptors..., cb*/) {
      var args = normArgs(arguments)
        , descriptors = args[0]
        , cb = args[1]
        ;

      descriptors = this.descriptors.normalize(descriptors);
      // TODO Re-factor: similar to what's in Model#_waitOrFetchData
      var req = {
        targets: descriptors
      , clientId: this._clientId
      , context: this.context(this.scopedContext)
      };
      var res = {
        fail: cb
      , send: function (data) {
          data = data.data;
          if (data.length === 0) {
            cb(null);
          } else if (data.length === 1) {
            // TODO For find, we must pass the cb an Array
            var datum = data[0]
              , path  = datum[0]
              , value = datum[1]
              , ver   = datum[2];
            cb(null, value);
          } else {
            throw new Error('Unimplemented');
          }
        }
      };
      this.middleware.fetch(req, res);
    }
    /**
     * @param {Number} ver is the version
     * @param {} clientStartId
     * @param {String} clientId
     * @param {Socket} socket
     * @param {Array} subs
     * @param {Boolean} shouldSubscribe
     * @api private
     */
  , _onSnapshotRequest: function (ver, clientStartId, clientId, socket, subs, shouldSubscribe) {
      var req = {
        startId: clientStartId
      , clientId: clientId
      , shouldSubscribe: shouldSubscribe
      , subs: subs
      , ver: ver
        // TODO Pass in proper context
      , context: this.context(this.scopedContext)
      };
      var res = {
        fail: function (err) {
          // TODO Should allow different kind of errors - e.g., "txnErr"
          socket.emit('fatalErr', err);
        }
      , send: function (channel, dataOrTxns, num) {
          socket.emit(channel, dataOrTxns, num);
        }
      };
      this.middleware.snapshot(req, res);
    }
  }
};
