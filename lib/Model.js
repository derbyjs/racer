var Model, lookup, _;
_ = require('./utils');
Model = module.exports = function() {
  var message, self, set, _lookup;
  self = this;
  self._data = {};
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
  set = function(path, value) {
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
  message = function(method, path, args) {
    return JSON.stringify([method, path, args]);
  };
  if (_.onServer) {
    self._send = function(message) {
      if (self._socket) {
        return self._socket.broadcast(message);
      }
    };
    return self._initSocket = function(socket) {
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
    return self._initSocket = function(socket) {
      socket.connect();
      return socket.on('message', function(message) {
        var args, method, path, _ref;
        return _ref = JSON.parse(message), method = _ref[0], path = _ref[1], args = _ref[2], _ref;
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
  if (next != null) {
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
    return lookup(next, props, len, i, path, get, funcs, funcInputs, isSet, onRef);
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