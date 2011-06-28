var Model, lookup, _;
var __slice = Array.prototype.slice;
_ = require('./util');
Model = module.exports = function() {
  var addTxn, nextTxnId, self, setters, txnCount, txnQueue, txns, _lookup;
  self = this;
  self._data = {};
  self._base = 0;
  self._clientId = '';
  txnCount = 0;
  nextTxnId = function() {
    return self._clientId + '.' + txnCount++;
  };
  txns = self._txns = {};
  txnQueue = self._txnQueue = [];
  addTxn = function(op) {
    var base, id, txn;
    base = self._base;
    txn = {
      op: op,
      base: base,
      sent: false
    };
    id = nextTxnId();
    txns[id] = txn;
    txnQueue.push(id);
    txn.sent = self._send(['txn', [base, id].concat(__slice.call(op))]);
    return id;
  };
  _lookup = function(path, options) {
    var props;
    if (options == null) {
      options = {};
    }
    if (path && path.split) {
      props = path.split('.');
      return lookup(self._data, props, props.length, 0, '', self.get, options.addPath, options.onRef);
    } else {
      return {
        obj: self._data,
        path: ''
      };
    }
  };
  self.get = function(path) {
    return _lookup(path).obj;
  };
  setters = self._setters = {
    set: function(path, value) {
      var out;
      out = _lookup(path, {
        addPath: true
      });
      try {
        return out.parent[out.prop] = value;
      } catch (err) {
        throw new Error('Model set failed on: ' + path);
      }
    },
    del: function(path) {
      var out;
      out = _lookup(path);
      try {
        return delete out.parent[out.prop];
      } catch (err) {
        throw new Error('Model delete failed on: ' + path);
      }
    }
  };
  self.set = function(path, value) {
    return addTxn(['set', path, value]);
  };
  if (_.onServer) {
    self._send = function(message) {
      if (self._socket) {
        return self._socket.broadcast(message);
      }
    };
    self._initSocket = function(socket) {
      return socket.on('connection', function(client) {
        return client.on('message', function(message) {
          var args, method, path, _ref;
          return _ref = JSON.parse(message), method = _ref[0], path = _ref[1], args = _ref[2], _ref;
        });
      });
    };
  } else {
    self._send = function(message) {
      if (self._socket) {
        self._socket.send(message);
        return true;
      } else {
        return false;
      }
    };
    self._initSocket = function(socket) {
      socket.connect();
      return socket.on('message', function(message) {
        var args, base, content, i, meta, method, txnId, type, _ref;
        _ref = JSON.parse(message), type = _ref[0], content = _ref[1], meta = _ref[2];
        if (type === 'txn') {
          base = content[0], txnId = content[1], method = content[2], args = 4 <= content.length ? __slice.call(content, 3) : [];
          setters[method].apply(self, args);
          self._base = base;
          delete txns[txnId];
          i = txnQueue.indexOf(txnId);
          if (i > -1) {
            return txnQueue.splice(i, 1);
          }
        }
      });
    };
  }
};
Model.prototype = {
  _setSocket: function(socket) {
    this._socket = socket;
    return this._initSocket(socket);
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
  }
};
lookup = function(obj, props, len, i, path, get, addPath, onRef) {
  var key, keyObj, next, prop, ref, refObj, remainder;
  prop = props[i++];
  next = obj[prop];
  if (next === void 0) {
    if (addPath) {
      next = obj[prop] = {};
    } else {
      return {
        obj: null
      };
    }
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
  if (i < len) {
    return lookup(next, props, len, i, path, get, addPath, onRef);
  } else {
    return {
      obj: next,
      path: path,
      parent: obj,
      prop: prop
    };
  }
};