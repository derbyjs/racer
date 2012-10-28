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

        // TODO Unify the code that is transforming the
        // queryMotifRegistry.queryJSON; it's scattered all over the place. See
        // pubSub.Store.js inside the subscribe middleware for similar code
        var subs = req.subs
          , subPayload = []
          , queryMotifRegistry = store._queryMotifRegistry;
        for (var i = 0, l = subs.length; i < l; i++) {
          var sub = subs[i];
          subPayload.push(
            (typeof sub === 'string')
            ? sub
            : queryMotifRegistry.queryJSON(sub)
          );
        }

        if (req.shouldSubscribe) {
          store._pubSub.subscribe(clientId, subPayload);
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

      middleware.fetch = createMiddleware();
      middleware.fetch.add(function (req, res, next) {
        var targets = req.targets
          , numTargets = targets.length

          , data = []
          , handles = []

          , finish = finishAfter(numTargets, next)
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
              , send: (function (i) {
                  return function (dataTriplets, single) {
                    data = data.concat(dataTriplets);
                    handles[i] = {data: dataTriplets, single: single};
                    if (++timesSendCalled === numTargets) {
                      var out = {
                        data: data
                      , handles: handles
                      };
                      store.emit('fetch', out, req.clientId, targets);
                      res.send(out);
                    }
                  }
                })(i)
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
          var handles = data.handles;
          handles = handles.map( function (x) {
            var triplets = x.data;
            // Each triplet is of the form [path, value, ver]
            if (x.single) {
              return triplets[0] && triplets[0][1];
            } else {
              return triplets.map(function (trip) {
                return trip[1];
              });
            }
          });
          cb.apply(null, [null].concat(handles));
        }
      };
      this.middleware.fetch(req, res);
    }

    /**
     * @param {Number} ver is the version
     * @param {} clientStartId
     * @param {String} clientId
     * @param {Socket} socket
     * @param {Array} subs are an array of descriptors,
     * e.g., ['a.*', ['users', {withName: ['Brian']}, 'one', 'some-queryId']]
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
