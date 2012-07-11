// TODO Add in redis adapter for version clock
var transaction = require('../transaction.server')
  , createStartIdVerifier = require('./shared').createStartIdVerifier

module.exports = function (opts) {
  var store = opts.store;
  return new Lww(store);
};

function Lww (store) {
  this._store = store;
  this._nextVer = 1;
  // TODO Remove this startId requirement for lww
  var self = this;
  this.startIdVerifier = createStartIdVerifier(function (callback) {
    callback(null, self._startId);
  });
  this.incrVer = this.incrVer.bind(this);
}

Lww.prototype = {
  // TODO Remove this startId requirement for lww
  startId: function (callback) {
    var startId = this._startId ||
                 (this._startId = (+new Date).toString(36));
    callback(null, startId);
  }

, incrVer: function (req, res, next) {
    var txn = req.data;
    var ver = req.newVer = this._nextVer++;
    transaction.setVer(txn, ver);
    return next();
  }

, flush: function (callback) { callback(null); }

, version: function (callback) {
    callback(null, this._nextVer - 1);
  }

, snapshotSince: function (params, callback) {
    var ver = params.ver
      , clientId = params.clientId
      , subs = params.subs;

    var req = {
      targets: subs
    , clientId: clientId
    , session: params.session
    , context: params.context
    };
    var res = {
      fail: callback
    , send: function (data) {
        callback(null, {data: data});
      }
    };
    this._store.middleware.fetch(req, res);
  }
};
