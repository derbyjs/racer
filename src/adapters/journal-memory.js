var transaction = require('../transaction.server');

exports = module.exports = plugin;
exports.useWith = { server: true, browser: false };
exports.decorate = 'racer';

function plugin (racer) {
  racer.registerAdapter('journal', 'Memory', JournalMemory);
}

function JournalMemory () {
  this.flush();
}

JournalMemory.prototype = {
  flush: function (cb) {
    this._txns = [];
    this._startId = (+new Date).toString(36);
    cb && cb();
  }

, startId: function (cb) { cb(null, this._startId); }

, version: function (cb) { cb(null, this._txns.length); }

, add: function (txn, opts, cb) {
    this._txns.push(txn);
    this.version(cb);
  }

  // TODO Make consistent with txnsSince?
, eachTxnSince: function (ver, cbs) {
    var each = cbs.each
      , done = cbs.done
      , txns = this._txns;
    if (ver === null) return done();

    function next (err) {
      if (err) return done(err);
      var txn = txns[ver++];
      if (txn) return each(null, txn, next);
      return done(null);
    }
    return next();
  }

, txnsSince: function (ver, clientId, pubSub, cb) {
    var since = [];

    if (! pubSub.hasSubscriptions(clientId))
      return cb(null, since);

    var txns = this._txns
      , txn;
    while (txn = txns[ver++]) {
      if (pubSub.subscribedTo(clientId, transaction.getPath(txn))) {
        since.push(txn);
      }
    }
    cb(null, since);
  }
};
