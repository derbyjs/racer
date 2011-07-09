var FLUSH_MS, MemoryAdapter, Stm, Store, transaction;
var __slice = Array.prototype.slice;
MemoryAdapter = require('./adapters/Memory');
Stm = require('./Stm');
transaction = require('./transaction');
FLUSH_MS = 500;
Store = module.exports = function() {
  var adapter, pending;
  this.adapter = adapter = new MemoryAdapter;
  this.stm = new Stm;
  this._pending = pending = {};
  setInterval(function() {
    var args, lastWrittenVer, method, nextVerToWrite, _ref, _results;
    lastWrittenVer = adapter._ver;
    nextVerToWrite = ++lastWrittenVer;
    _results = [];
    while (pending[nextVerToWrite]) {
      _ref = pending[nextVerToWrite], method = _ref[0], args = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
      adapter[method].apply(adapter, args);
      _results.push(delete pending[nextVerToWrite++]);
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
    return this.commit([0, '_.0', 'set', path, value], callback);
  },
  del: function(path, callback) {
    return this.commit([0, '_.0', 'del', path], callback);
  },
  commit: function(txn, callback) {
    var pending;
    pending = this._pending;
    return this.stm.commit(txn, function(err, ver) {
      if (err) {
        return callback && callback(err);
      }
      return pending[ver] = transaction.op(txn).concat(ver, callback);
    });
  }
};