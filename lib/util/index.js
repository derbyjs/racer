var isServer = typeof window === 'undefined';
var isProduction = isServer && process.env.NODE_ENV === 'production';

module.exports = {
  isServer: isServer
, serverRequire: serverRequire
, isProduction: isProduction
, merge: merge
, hasKeys: hasKeys
, escapeRegExp: escapeRegExp
, deepEqual: deepEqual
, deepCopy: deepCopy
, copyObject: copyObject
, keyOf: keyOf
, indexOf: indexOf
, indexOfFn: indexOfFn
, isArguments: isArguments
, deepIndexOf: deepIndexOf
, equalsNaN: equalsNaN
, equal: equal
, noop: noop
, asyncGroup: asyncGroup
, mayImpactAny: mayImpactAny
, mayImpact: mayImpact
};

var racer = require('../racer');

var toString = Object.prototype.toString;
var hasOwnProperty = Object.prototype.hasOwnProperty;

function serverRequire(name) {
  if (!isServer) return;
  // Tricks Browserify into not logging a warning
  var _require = require;
  return _require(name);
}

function asyncGroup(cb) {
  var group = new AsyncGroup(cb);
  return function asyncGroupAdd() {
    return group.add();
  };
}
function AsyncGroup(cb) {
  this.cb = cb;
  this.isDone = false;
  this.count = 0;
}
AsyncGroup.prototype.add = function() {
  this.count++;
  var self = this;
  return function(err) {
    self.count--;
    if (self.isDone) return;
    if (err) {
      self.isDone = true;
      self.cb(err);
      return;
    }
    if (self.count > 0) return;
    self.isDone = true;
    self.cb();
  }
};

function mayImpactAny(segmentsList, testSegments) {
  for (var i = 0, len = segmentsList.length; i < len; i++) {
    if (mayImpact(segmentsList[i], testSegments)) return true;
  }
  return false;
}

function mayImpact(segments, testSegments) {
  var len = Math.min(segments.length, testSegments.length);
  for (var i = 0; i < len; i++) {
    if (segments[i] !== testSegments[i]) return false;
  }
  return true;
}

function merge (to, from) {
  for (var key in from) to[key] = from[key];
  return to;
}

function hasKeys (obj, ignore) {
  for (var key in obj)
    if (key !== ignore) return true;
  return false;
}

/**
   * Escape a string to be used as the source of a RegExp such that it matches
   * literally.
   */
function escapeRegExp(s) {
  return s.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, '\\$&');
}

function isArguments(obj) {
  return toString.call(obj) === '[object Arguments]';
}

/**
 * Modified from node's assert.js
 */
function deepEqual (actual, expected, ignore) {
  // 7.1. All identical values are equivalent, as determined by ===.
  if (actual === expected) return true;

  // 7.2. If the expected value is a Date object, the actual value is
  // equivalent if it is also a Date object that refers to the same time.
  if (actual instanceof Date && expected instanceof Date)
    return actual.getTime() === expected.getTime();

  if (typeof actual === 'function' && typeof expected === 'function')
    return actual === expected || actual.toString() === expected.toString();

  // 7.3. Other pairs that do not both pass typeof value == 'object',
  // equivalence is determined by ==.
  if (typeof actual !== 'object' && typeof expected !== 'object')
    return actual === expected;

  // 7.4. For all other Object pairs, including Array objects, equivalence is
  // determined by having the same number of owned properties (as verified
  // with Object.prototype.hasOwnProperty.call), the same set of keys
  // (although not necessarily the same order), equivalent values for every
  // corresponding key, and an identical 'prototype' property. Note: this
  // accounts for both named and indexed properties on Arrays.
  if (ignore) {
    var ignoreMap = {}
      , i = ignore.length
    while (i--) {
      ignoreMap[ignore[i]] = true;
    }
  }
  return objEquiv(actual, expected, ignoreMap);
}

function keysWithout (obj, ignoreMap) {
  var out = []
    , key
  for (key in obj) {
    if (!ignoreMap[key] && hasOwnProperty.call(obj, key)) out.push(key);
  }
  return out;
}

/**
 * Modified from node's assert.js
 */
function objEquiv (a, b, ignoreMap) {
  var i, key, ka, kb;

  if (a == null || b == null) return false;

  // an identical 'prototype' property.
  if (a.prototype !== b.prototype) return false;

  //~~~I've managed to break Object.keys through screwy arguments passing.
  //   Converting to array solves the problem.
  if (isArguments(a)) {
    if (! isArguments(b)) return false;
    a = pSlice.call(a);
    b = pSlice.call(b);
    return deepEqual(a, b);
  }
  try {
    if (ignoreMap) {
      ka = keysWithout(a, ignoreMap);
      kb = keysWithout(b, ignoreMap);
    } else {
      ka = Object.keys(a);
      kb = Object.keys(b);
    }
  } catch (e) {
    // happens when one is a string literal and the other isn't
    return false;
  }
  // having the same number of owned properties (keys incorporates
  // hasOwnProperty)
  if (ka.length !== kb.length) return false;

  // the same set of keys (although not necessarily the same order),
  ka.sort();
  kb.sort();

  //~~~cheap key test
  i = ka.length;
  while (i--) {
    if (ka[i] !== kb[i]) return false;
  }

  //equivalent values for every corresponding key, and
  //~~~possibly expensive deep test
  i = ka.length;
  while (i--) {
    key = ka[i];
    if (! deepEqual(a[key], b[key])) return false;
  }
  return true;
}

// TODO Test this
function deepCopy (obj) {
  if (obj === null) return null;
  if (obj instanceof Date) return new Date(obj);
  if (typeof obj === 'object') {
    var copy;
    if (Array.isArray(obj)) {
      copy = [];
      for (var i = obj.length; i--; ) copy[i] = deepCopy(obj[i]);
      return copy;
    }
    copy = {}
    for (var k in obj) copy[k] = deepCopy(obj[k]);
    return copy;
  }
  return obj;
}


function copyObject(object) {
  var out = new object.constructor;
  for (var key in object) {
    if (object.hasOwnProperty(key)) {
      out[key] = object[key];
    }
  }
  return out;
}

function keyOf(object, item) {
  if (item && item.id && object[item.id] === item) {
    return item.id;
  }
  for (var key in object) {
    if (object[key] === item) return key;
  }
}

function indexOf (list, obj, isEqual) {
  for (var i = 0, l = list.length; i < l; i++)
    if (isEqual(obj, list[i])) return i;
  return -1;
}

function indexOfFn (list, fn) {
  for (var i = 0, l = list.length; i < l; i++) {
    if (fn(list[i])) return i;
  }
  return -1;
}

function deepIndexOf (list, obj) {
  return indexOf(list, obj, deepEqual);
}

function equalsNaN(x) {
  return x !== x;
}

function equal(a, b) {
  return (a === b) || (equalsNaN(a) && equalsNaN(b));
}

function noop() {}
