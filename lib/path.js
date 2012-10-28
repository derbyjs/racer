var util = require('./util')
  , hasKeys = util.hasKeys;

util.path = exports;

// Test to see if path name contains a segment that starts with an underscore.
// Such a path is private to the current session and should not be stored
// in persistent storage or synced with other clients.
exports.isPrivate = function isPrivate (name) { return /(?:^_)|(?:\._)/.test(name); };

exports.isPattern = function isPattern (x) { return -1 === x.indexOf('*'); };

function createEachMatch (matchHandler, fields) {
  fields = fields.split('');
  return function eachMatch (match, index, pattern) {
    // Escape special characters
    if (~fields.indexOf(match) && match in matchHandler) {
      return matchHandler[match];
    }

    // An asterisk matches any single path segment in the middle and any path
    // or paths at the end
    if (pattern.length - index === 1) return '(.+)';

    return '([^.]+)';
  }
}
exports.eventRegExp = function eventRegExp (pattern) {
  if (pattern instanceof RegExp) return pattern;
  var self = this;
  var inner;
  var matchHandler = {
    '.': '\\.'
  , '$': '\\$'
  , '^': '\\^'
  , '[': '\\['
  , ']': '\\]'

    // Commas can be used for or, as in path.(one,two)
  , ',': '|'
  };
  var eachMatch;
  if (pattern.substring(0, 9) === '_$queries') {
    eachMatch = createEachMatch(matchHandler, '.*$^[]');
    inner = '_\\$queries\\.' + pattern.substring(10).replace(/[.*$^\[\]]/g, eachMatch);
  } else {
    eachMatch = createEachMatch(matchHandler, ',.*$');
    inner = pattern.replace(/[,.*$]/g, eachMatch);
  }
  return new RegExp('^' + inner + '$');
};

exports.regExp = function regExp (pattern) {
  // Match anything if there is no pattern or the pattern is ''
  if (! pattern) return /^/;

  return new RegExp('^' + pattern.replace(/[.*$]/g, function (match, index) {
    // Escape periods
    if (match === '.') return '\\.';

    if (match === '$') return '\\$';

    // An asterisk matches any single path segment in the middle
    return '[^.]+';

    // All subscriptions match the root and any path below the root
  }) + '(?:\\.|$)');
};

// Create regular expression matching the path or any of its parents
exports.regExpPathOrParent = function regExpPathOrParent (path, levels) {
  var p = ''
    , parts = path.split('.')
    , source = [];

  for (var i = 0, l = parts.length - (levels || 0); i < l; i++) {
    var segment = parts[i];
    p += i ? '\\.' + segment
           : segment;
    source.push( '(?:' + p + ')' );
  }
  source = source.join('|');
  return new RegExp('^(?:' + source + ')$');
};

// Create regular expression matching any of the paths or child paths of any of
// the paths
exports.regExpPathsOrChildren = function regExpPathsOrChildren (paths) {
  var source = [];
  for (var i = 0, l = paths.length; i < l; i++) {
    var path = paths[i];
    source.push( '(?:' + path + "(?:\\..+)?)" );
  }
  source = source.join('|');
  return new RegExp('^(?:' + source + ')$');
};

exports.lookup = lookup;

function lookup (path, obj) {
  if (!obj) return;
  if (path.indexOf('.') === -1) return obj[path];

  var parts = path.split('.');
  for (var i = 0, l = parts.length; i < l; i++) {
    if (!obj) return obj;

    var prop = parts[i];
    obj = obj[prop];
  }
  return obj;
};

exports.assign = assign;

function assign (obj, path, val) {
  var parts = path.split('.')
    , lastIndex = parts.length - 1;
  for (var i = 0, l = parts.length; i < l; i++) {
    var prop = parts[i];
    if (i === lastIndex) obj[prop] = val;
    else                 obj = obj[prop] || (obj[prop] = {});
  }
};

exports.objectWithOnly = function objectWithOnly (obj, paths) {
  var projectedDoc = {};
  for (var i = 0, l = paths.length; i < l; i++) {
    var path = paths[i];
    assign(projectedDoc, path, lookup(path, obj));
  }
  return projectedDoc;
};

exports.objectExcept = function objectExcept (from, exceptions) {
  if (! from) return;
  var to = Array.isArray(from) ? [] : {};
  for (var key in from) {
    // Skip exact exception matches
    if (~exceptions.indexOf(key)) continue;

    var nextExceptions = [];
    for (var i = exceptions.length; i--; ) {
      var except = exceptions[i]
        , periodPos = except.indexOf('.')
        , prefix = except.substring(0, periodPos);
      if (prefix === key) {
        nextExceptions.push(except.substring(periodPos + 1, except.length));
      }
    }
    if (nextExceptions.length) {
      var nested = objectExcept( from[key], nextExceptions );
      if (hasKeys(nested)) to[key] = nested;
    } else {
      if (Array.isArray(from)) key = parseInt(key, 10);
      to[key] = from[key];
    }
  }
  return to;
};

/**
 * TODO Rename to isPrefixOf because more String generic? (no path implication)
 * Returns true if `prefix` is a prefix of `path`. Otherwise, returns false.
 * @param {String} prefix
 * @param {String} path
 * @return {Boolean}
 */
exports.isSubPathOf = function isSubPathOf (path, fullPath) {
  return path === fullPath.substring(0, path.length);
};

exports.split = function split (path) {
  return path.split(/\.?[(*]\.?/);
};

exports.expand = function expand (path) {
  // Remove whitespace and line break characters
  path = path.replace(/[\s\n]/g, '');

  // Return right away if path doesn't contain any groups
  if (! ~path.indexOf('(')) return [path];

  // Break up path groups into a list of equivalent paths that contain only
  // names and *
  var paths = [''], out = []
    , stack = { paths: paths, out: out}
    , lastClosed;
  while (path) {
    var match = /^([^,()]*)([,()])(.*)/.exec(path);
    if (! match) return out.map( function (val) { return val + path; });
    var pre = match[1]
      , token = match[2];
    path = match[3]

    if (pre) {
      paths = paths.map( function (val) { return val + pre; });
      if (token !== '(') {
        var out = lastClosed ? paths : out.concat(paths);
      }
    }
    lastClosed = false;
    if (token === ',') {
      stack.out = stack.out.concat(paths);
      paths = stack.paths;
    } else if (token === '(') {
      out = [];
      stack = { parent: stack, paths: paths, out: out };
    } else if (token === ')') {
      lastClosed = true;
      paths = out = stack.out.concat(paths);
      stack = stack.parent;
    }
  }
  return out;
};

// Given a `path`, returns an array of length 3 with the namespace, id, and
// relative path to the attribute
exports.triplet = function triplet (path) {
  var parts = path.split('.');
  return [parts[0], parts[1], parts.slice(2).join('.')];
};

exports.subPathToDoc = function subPathToDoc (path) {
  return path.split('.').slice(0, 2).join('.');
};

exports.join = function join () {
  var joinedPath = [];
  for (var i = 0, l = arguments.length; i < l; i++) {
    var component = arguments[i];
    if (typeof component === 'string') {
      joinedPath.push(component);
    } else if (Array.isArray(component)) {
      joinedPath.push.apply(joinedPath, component);
    } else {
      throw new Error('path.join only takes strings and Arrays as arguments');
    }
  }
  return joinedPath.join('.');
};

exports.isImmediateChild = function (ns, path) {
  var rest = path.substring(ns.length + /* dot */ 1);
  return -1 === rest.indexOf('.');
};

exports.isGrandchild = function (ns, path) {
  var rest = path.substring(ns.length + /* dot */ 1);
  return -1 !== rest.indexOf('.');
};
