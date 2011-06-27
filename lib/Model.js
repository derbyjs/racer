var Model, lookup, _;
_ = require('./util');
Model = module.exports = function() {
  var self, _lookup;
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
  return self;
};
Model.prototype = {
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