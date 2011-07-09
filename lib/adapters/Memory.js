var Memory, Model;
Model = require('../Model');
Memory = module.exports = function() {
  this._data = {};
  this._ver = 0;
};
Memory.prototype = {
  flush: function(callback) {
    this._data = {};
    if (callback) {
      return callback(null);
    }
  },
  _set: Model.prototype._set,
  set: function(path, value, ver, callback) {
    this._set(path, value);
    this._ver = ver;
    if (callback) {
      return callback(null);
    }
  },
  _del: Model.prototype._del,
  del: function(path, callback) {
    this._del(path, value);
    if (callback) {
      return callback(null);
    }
  },
  get: function(path, callback) {
    var obj, value;
    obj = this._data;
    value = path ? this._lookup(path, {
      obj: obj
    }).obj : obj;
    if (callback) {
      return callback(null, value, this._ver);
    }
  },
  _lookup: Model.prototype._lookup
};