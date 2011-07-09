var Model;
var __slice = Array.prototype.slice;
Model = module.exports = function(clientId) {
  var self, txnQueue, txns;
  if (clientId == null) {
    clientId = '';
  }
  self = this;
  self._data = {};
  self._base = 0;
  self._clientId = clientId;
  self._subs = {};
  self._txnCount = 0;
  self._txns = txns = {};
  self._txnQueue = txnQueue = [];
  self._onTxn = function(txn) {
    var args, base, method, path, txnId;
    base = txn[0], txnId = txn[1], method = txn[2], path = txn[3], args = 5 <= txn.length ? __slice.call(txn, 4) : [];
    self['_' + method].apply(self, txn.slice(3));
    self._base = base;
    self._removeTxn(txnId);
    return self._emit(method, path, args);
  };
  self.get = function(path) {
    var args, i, len, method, obj, txn, _ref;
    if (len = txnQueue.length) {
      obj = Object.create(self._data);
      i = 0;
      while (i < len) {
        txn = txns[txnQueue[i++]];
        _ref = txn.op, method = _ref[0], args = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
        args.push({
          obj: obj,
          proto: true
        });
        self['_' + method].apply(self, args);
      }
    } else {
      obj = self._data;
    }
    if (path) {
      return self._lookup(path, {
        obj: obj
      }).obj;
    } else {
      return obj;
    }
  };
};
Model.prototype = {
  _send: function() {
    return false;
  },
  _setSocket: function(socket, config) {
    socket.on('txn', this._onTxn);
    socket.on('txnFail', this._removeTxn);
    return this._send = function(txn) {
      socket.emit('txn', txn);
      return true;
    };
  },
  on: function(method, pattern, callback) {
    var re, sub, subs;
    re = new RegExp('^' + pattern.replace(/(^|\.)((?:[^\.\|]+\|)(?:[^\.\|]+\|?)*)(\.|$)/g, '$1($2)$3').replace(/\./g, '\\.').replace(/\*/g, '([^\\.]+)') + '$');
    sub = [re, callback];
    subs = this._subs;
    if (subs[method] === void 0) {
      return subs[method] = [sub];
    } else {
      return subs[method].push(sub);
    }
  },
  _emit: function(method, path, args) {
    var re, sub, subs, _i, _len, _results;
    if (!(subs = this._subs[method])) {
      return;
    }
    _results = [];
    for (_i = 0, _len = subs.length; _i < _len; _i++) {
      sub = subs[_i];
      re = sub[0];
      _results.push(re.test(path) ? sub[1].apply(null, re.exec(path).slice(1).concat(args)) : void 0);
    }
    return _results;
  },
  _nextTxnId: function() {
    return this._clientId + '.' + this._txnCount++;
  },
  _addTxn: function() {
    var args, base, id, method, op, path, txn;
    method = arguments[0], path = arguments[1], args = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
    base = this._base;
    op = Array.prototype.slice.call(arguments);
    txn = {
      op: op,
      base: base,
      sent: false
    };
    id = this._nextTxnId();
    this._txns[id] = txn;
    this._txnQueue.push(id);
    this._emit(method, path, args);
    txn.sent = this._send([base, id].concat(__slice.call(op)));
    return id;
  },
  _removeTxn: function(txnId) {
    var i, txnQueue;
    delete this._txns[txnId];
    txnQueue = this._txnQueue;
    if (~(i = txnQueue.indexOf(txnId))) {
      return txnQueue.splice(i, 1);
    }
  },
  _lookup: function(path, _arg) {
    var addPath, get, i, key, keyObj, len, next, obj, onRef, prop, props, proto, ref, refObj, remainder;
    obj = _arg.obj, addPath = _arg.addPath, proto = _arg.proto, onRef = _arg.onRef;
    next = obj || this._data;
    get = this.get;
    props = path && path.split ? path.split('.') : [];
    path = '';
    i = 0;
    len = props.length;
    while (i < len) {
      obj = next;
      prop = props[i++];
      if (proto && !Object.prototype.isPrototypeOf(obj)) {
        obj = Object.create(obj);
      }
      next = obj[prop];
      if (next === void 0) {
        if (!addPath) {
          return {
            obj: null
          };
        }
        next = obj[prop] = {};
      }
      if (ref = next.$r) {
        refObj = get(ref);
        if (key = next.$k) {
          keyObj = get(key);
          path = ref + '.' + keyObj;
          next = refObj[keyObj];
        } else {
          path = ref;
          next = refObj;
        }
        if (onRef) {
          remainder = [path].concat(props.slice(i));
          onRef(key, remainder.join('.'));
        }
      } else {
        path = path ? path + '.' + prop : prop;
      }
    }
    return {
      obj: next,
      path: path,
      parent: obj,
      prop: prop
    };
  },
  set: function(path, value) {
    this._addTxn('set', path, value);
    return value;
  },
  del: function(path) {
    return this._addTxn('del', path);
  },
  ref: function(ref, key) {
    if (key != null) {
      return {
        $r: ref,
        $k: key
      };
    } else {
      return {
        $r: ref
      };
    }
  },
  _set: function(path, value, options) {
    var out;
    if (options == null) {
      options = {};
    }
    options.addPath = true;
    out = this._lookup(path, options);
    try {
      return out.parent[out.prop] = value;
    } catch (err) {
      throw new Error('Model set failed on: ' + path);
    }
  },
  _del: function(path, options) {
    var key, obj, out, parent, prop, value, _ref;
    if (options == null) {
      options = {};
    }
    out = this._lookup(path, options);
    parent = out.parent;
    prop = out.prop;
    try {
      if (options.proto) {
        if (prop in parent.__proto__) {
          obj = {};
          _ref = parent.__proto__;
          for (key in _ref) {
            value = _ref[key];
            if (key !== prop) {
              obj[key] = typeof value === 'object' ? Object.create(value) : value;
            }
          }
          parent.__proto__ = obj;
        }
      }
      return delete parent[prop];
    } catch (err) {
      throw new Error('Model delete failed on: ' + path);
    }
  }
};