var FLUSH_MS, MemoryAdapter, Stm, Store, transaction;
MemoryAdapter = require('./adapters/Memory');
Stm = require('./Stm');
transaction = require('./transaction');
FLUSH_MS = 500;
Store = module.exports = function() {
  var adapter, maxVer, pending, ver;
  this.adapter = adapter = new MemoryAdapter;
  this.stm = new Stm;
  pending = {};
  ver = 1;
  maxVer = 0;
  this._queue = function(txn, ver) {
    pending[ver] = txn;
    return maxVer = ver;
  };
  setInterval(function() {
    var method, opArgs, txn, _results;
    _results = [];
    while (ver <= maxVer) {
      if (!(txn = pending[ver])) {
        break;
      }
      method = transaction.method(txn);
      opArgs = transaction.opArgs(txn);
      opArgs.push(ver, function(err) {
        if (err) {
          throw err;
        }
      });
      adapter[method].apply(adapter, opArgs);
      delete pending[ver];
      _results.push(ver++);
    }
    return _results;
  }, FLUSH_MS);
};
Store.prototype = {
  flush: function(callback) {
    var cb, done;
    done = false;
    cb = function(err) {
      if (callback && done || err) {
        callback(err, callback = null);
      }
      return done = true;
    };
    this.adapter.flush(cb);
    return this.stm.flush(cb);
  },
  get: function(path, callback) {
    return this.adapter.get(path, callback);
  },
  set: function(path, value, callback) {
    return this._commit([0, '_.0', 'set', path, value], callback);
  },
  del: function(path, callback) {
    return this._commit([0, '_.0', 'del', path], callback);
  },
  _commit: function(txn, callback) {
    var queue;
    queue = this._queue;
    return this.stm.commit(txn, function(err, ver) {
      txn[0] = ver;
      if (callback) {
        callback(err, txn);
      }
      if (err) {
        return;
      }
      return queue(txn, ver);
    });
  }
};