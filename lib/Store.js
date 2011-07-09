var MemoryAdapter, Stm, Store;
MemoryAdapter = require('./adapters/Memory');
Stm = require('./Stm');
Store = module.exports = function() {
  this.adapter = new MemoryAdapter;
  this.stm = new Stm;
};
Store.prototype = {
  flush: function(callback) {
    var cb, done;
    done = false;
    cb = function(err) {
      done = true;
      if (callback && done || err) {
        return callback(err);
      }
    };
    this.adapter.flush(cb);
    return this.stm.flush(cb);
  },
  get: function(path, callback) {
    return this.adapter.get(path, callback);
  },
  set: function(path, value, callback) {
    var adapter;
    adapter = this.adapter;
    return this.stm.commit([0, 'store.0', 'set', path, value], function(err, ver) {
      if (err) {
        return callback && callback(err);
      }
      return adapter.set(path, value, ver, callback);
    });
  },
  "delete": function(path, callback) {
    var adapter;
    adapter = this.adapter;
    return this.stm.commit([0, 'store.0', 'del', path], function() {
      return function(err, ver) {
        if (err) {
          return callback && callback(err);
        }
        return adapter.set(path, value, ver, callback);
      };
    });
  }
};