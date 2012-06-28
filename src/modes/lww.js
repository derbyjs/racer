// TODO Add in redis adapter for version clock
var transaction = require('../transaction.server');

module.exports = function (opts) {
  var store = opts.store;
  return new Lww(store);
};

function Lww (store) {
  this._store = store;
  this._nextVer = 1;
}

Lww.prototype = {
  // TODO Remove this startId requirement for lww
  startId: function (callback) {
    var startId = this._startId ||
                 (this._startId = (+new Date).toString(36));
    callback(null, startId);
  }

, commit: function (txn, callback) {
    var ver = this._nextVer++;
    transaction.setVer(txn, ver);
    this._store._finishCommit(txn, ver, callback);
  }

, flush: function (callback) { callback(null); }

, version: function (callback) {
    callback(null, this._nextVer - 1);
  }

, snapshotSince: function (params, callback) {
    var ver = params.ver
      , clientId = params.clientId
      , subs = params.subs;
    this._store.fetch(clientId, subs, function (err, data) {
      if (err) callback(err);
      else callback(null, {data: data});
    });
  }

  // TODO Remove this startId requirement for lww
, checkStartMarker: function (clientStartId, callback) {
    if (clientStartId !== this._startId) {
      var err = "clientStartId != startId (#{clientStartId} != #{@_startId})";
      callback(err);
    }
    callback(null);
  }
};
