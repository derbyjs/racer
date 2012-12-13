var speculative = require('./util/speculative')
  , isPrivate = require('./path').isPrivate
  , treeLookup = require('./tree').lookup
  , __slice = [].slice

module.exports = Memory;
function Memory() {
  this.flush();
}
Memory.prototype = {
  flush: flush
, init: init
, eraseNonPrivate: eraseNonPrivate
, toJSON: toJSON
, setVersion: setVersion
, get: get
, set: set
, del: del
, push: push
, unshift: unshift
, insert: insert
, pop: pop
, shift: shift
, remove: remove
, move: move
, _applyArrayMethod: applyArrayMethod
, _arrayLookupSet: arrayLookupSet
, _lookupSet: lookupSet
};

function flush() {
  this._data = {
    world: {}
  , splits: {}
  };
  this.version = 0;
}
function init(obj) {
  this.flush()
  this._data.world = obj.data;
  this.version = obj.ver;
}
function eraseNonPrivate() {
  var world = this._data.world
    , path
  for (path in world) {
    if (isPrivate(path)) continue;
    delete world[path];
  }
}
function toJSON() {
  return {
    data: this._data.world,
    ver: this.version
  };
}
function setVersion(ver) {
  return this.version = Math.max(this.version, ver);
}

function get(path, data, getRef) {
  data || (data = this._data);
  return path ? treeLookup(data, path, {getRef: getRef}).node : data.world;
}

function set(path, value, ver, data) {
  this.setVersion(ver);
  var tuple = lookupSet(path, data || this._data, ver == null, 'object')
    , obj = tuple[0]
    , parent = tuple[1]
    , prop = tuple[2]
  parent[prop] = value;
  var segments = path.split('.');
  if (segments.length === 2 &&
      value && value.constructor === Object &&
      value.id == null) {
    value.id = segments[1];
  }
  return obj;
}

function del(path, ver, data) {
  this.setVersion(ver);
  data || (data = this._data);
  var isSpeculative = (ver == null)
    , tuple = lookupSet(path, data, isSpeculative)
    , obj = tuple[0]
    , parent = tuple[1]
    , prop = tuple[2]
    , grandparent, index, parentClone, parentPath, parentProp
  if (ver != null) {
    if (parent) delete parent[prop];
    return obj;
  }
  // If speculatiave, replace the parent object with a clone that
  // has the desired item deleted
  if (!parent) {
    return obj;
  }
  if (~(index = path.lastIndexOf('.'))) {
    parentPath = path.substr(0, index);
    tuple = lookupSet(parentPath, data, isSpeculative);
    parent = tuple[0];
    grandparent = tuple[1];
    parentProp = tuple[2];
  } else {
    parent = data.world;
    grandparent = data;
    parentProp = 'world';
  }
  parentClone = speculative.clone(parent);
  delete parentClone[prop];
  grandparent[parentProp] = parentClone;
  return obj;
}

// push(path, args..., ver, data)
function push() {
  return this._applyArrayMethod(arguments, 1, function(arr, args) {
    return arr.push.apply(arr, args);
  });
}

// unshift(path, args..., ver, data)
function unshift() {
  return this._applyArrayMethod(arguments, 1, function(arr, args) {
    return arr.unshift.apply(arr, args);
  });
}

// insert(path, index, args..., ver, data)
function insert(path, index) {
  return this._applyArrayMethod(arguments, 2, function(arr, args) {
    arr.splice.apply(arr, [index, 0].concat(args));
    return arr.length;
  });
}

function applyArrayMethod(argumentsObj, offset, fn) {
  if (argumentsObj.length < offset + 3) throw new Error('Not enough arguments');
  var path = argumentsObj[0]
    , i = argumentsObj.length - 2
    , args = __slice.call(argumentsObj, offset, i)
    , ver = argumentsObj[i++]
    , data = argumentsObj[i++]
    , arr = this._arrayLookupSet(path, ver, data)
  return fn(arr, args);
}

function pop(path, ver, data) {
  var arr = this._arrayLookupSet(path, ver, data);
  return arr.pop();
}

function shift(path, ver, data) {
  var arr = this._arrayLookupSet(path, ver, data);
  return arr.shift();
}

function remove(path, index, howMany, ver, data) {
  var arr = this._arrayLookupSet(path, ver, data);
  return arr.splice(index, howMany);
}

function move(path, from, to, howMany, ver, data) {
  var arr = this._arrayLookupSet(path, ver, data)
    , len = arr.length
    , values
  // Cast to numbers
  from = +from;
  to = +to;
  // Make sure indices are positive
  if (from < 0) from += len;
  if (to < 0) to += len;
  // Remove from old location
  values = arr.splice(from, howMany);
  // Insert in new location
  arr.splice.apply(arr, [to, 0].concat(values));
  return values;
}

function arrayLookupSet(path, ver, data) {
  this.setVersion(ver);
  var arr = lookupSet(path, data || this._data, ver == null, 'array')[0];
  if (!Array.isArray(arr)) {
    throw new TypeError(arr + ' is not an Array');
  }
  return arr;
}

function lookupSet(path, data, isSpeculative, pathType) {
  var props = path.split('.')
    , len = props.length
    , i = 0
    , curr = data.world = isSpeculative ? speculative.create(data.world) : data.world
    , firstProp = props[0]
    , parent, prop

  while (i < len) {
    prop = props[i++];
    parent = curr;
    curr = curr[prop];

    // Create empty objects implied by the path
    if (curr != null) {
      if (isSpeculative && typeof curr === 'object') {
        curr = parent[prop] = speculative.create(curr);
      }
    } else {
      if (pathType === 'object') {
        // Cover case where property is a number and it NOT a doc id
        // We treat the value at <collection>.<docid> as an Object, not an Array
        if ((i !== 1 || isPrivate(firstProp)) && /^[0-9]+$/.test(props[i])) {
          curr = parent[prop] = isSpeculative ? speculative.createArray() : [];
        } else if (i !== len) {
          curr = parent[prop] = isSpeculative ? speculative.createObject() : {};
          if (i === 2 && !isPrivate(firstProp)) {
            curr.id = prop;
          }
        }
      } else if (pathType === 'array') {
        if (i === len) {
          curr = parent[prop] = isSpeculative ? speculative.createArray() : [];
        } else {
          curr = parent[prop] = isSpeculative ? speculative.createObject() : {};
          if (i === 2 && !isPrivate(firstProp)) {
            curr.id = prop;
          }
        }
      } else {
        if (i !== len) {
          parent = curr = void 0;
        }
        return [curr, parent, prop];
      }
    }
  }
  return [curr, parent, prop];
}
