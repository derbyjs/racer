var Model, lookup, _;
_ = require('./util');
Model = module.exports = function() {
  var addTxn, nextTxnId, self, txnCount, txnQueue, txns, _lookup;
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
    var id, txn;
    txn = {
      op: op,
      base: self._base,
      sent: false
    };
    id = nextTxnId();
    txns[id] = txn;
    txnQueue.push(id);
    return id;
  };
  _lookup = function(path, options) {
    var props;
    if (options == null) {
      options = {};
    }
    if (path && path.split) {
      props = path.split('.');
      return lookup(self._data, props, props.length, 0, '', self.get, options.isSet, options.onRef);
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
  self._set = function(path, value) {
    var out;
    out = _lookup(path, {
      isSet: true
    });
    try {
      out["return"] = out.obj[out.prop] = value;
    } catch (err) {
      throw new Error('Model set failed on: ' + path);
    }
    return out;
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
        return self._socket.send(message);
      }
    };
    self._initSocket = function(socket) {
      socket.connect();
      return socket.on('message', function(message) {
        var args, base, method, path, txnId, _ref;
        return _ref = JSON.parse(message), base = _ref[0], txnId = _ref[1], method = _ref[2], path = _ref[3], args = _ref[4], _ref;
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
lookup = function(obj, props, len, i, path, get, isSet, onRef) {
  var key, keyObj, next, prop, ref, refObj, remainder;
  prop = props[i++];
  next = obj[prop];
  if (next === void 0) {
    if (isSet) {
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
    return lookup(next, props, len, i, path, get, isSet, onRef);
  } else {
    if (isSet) {
      return {
        obj: obj,
        prop: prop,
        path: path
      };
    } else {
      return {
        obj: next,
        path: path
      };
    }
  }
};