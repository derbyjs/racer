// TODO Add in redis adapter for version clock
var transaction = require('../transaction.server')

module.exports = function (opts) {
  var store = opts.store;
  return new Lww(store);
};

function Lww (store) {
  this._store = store;
  this._nextVer = 1;

  var self = this;
  this.incrVer = function (req, res, next) {
    var txn = req.data;
    var ver = req.newVer = self._nextVer++;
    transaction.setVer(txn, ver);
    return next();
  };
}

Lww.prototype = {
  // TODO Remove startId altogether for LWW?
  startId: function (callback) {
    callback(null, -1);
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
