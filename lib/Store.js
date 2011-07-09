var FLUSH_MS, MemoryAdapter, Stm, Store;
var __slice = Array.prototype.slice;
MemoryAdapter = require('./adapters/Memory');
Stm = require('./Stm');
FLUSH_MS = 500;
Store = module.exports = function() {
  var adapter, pending;
  this.adapter = adapter = new MemoryAdapter;
  this.stm = new Stm;
  this._pendingSets = pending = {};
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
    var adapter, pending;
    adapter = this.adapter;
    pending = this._pendingSets;
    return this.stm.commit([0, '_.0', 'set', path, value], function(err, ver) {
      if (err) {
        return callback && callback(err);
      }
      return pending[ver] = ['set', path, value, ver, callback];
    });
  },
  del: function(path, callback) {
    var adapter;
    adapter = this.adapter;
    return this.stm.commit([0, '_.0', 'del', path], function() {
      return function(err, ver) {
        if (err) {
          return callback && callback(err);
        }
        return adapter.del(path, callback);
      };
    });
  }
};