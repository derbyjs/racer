var refUtils = require('./util')
  , derefPath = refUtils.derefPath
  , addListener = refUtils.addListener
  , pathUtil = require('../path')
  , joinPaths = pathUtil.join
  , regExpPathOrParent = pathUtil.regExpPathOrParent
  , lookup = pathUtil.lookup
  , indexOf = require('../util').indexOf
  , Model = require('../Model')
  ;

exports = module.exports = createRef;

function createRef (model, from, to, key, hardLink) {
  if (!from)
    throw new Error('Missing `from` in `model.ref(from, to, key)`');
  if (!to)
    throw new Error('Missing `to` in `model.ref(from, to, key)`');

  if (key) {
    var getter = createGetterWithKey(to, key, hardLink);
    setupRefWithKeyListeners(model, from, to, key, getter);
    return getter;
  }
  var getter = createGetterWithoutKey(to, hardLink);
  setupRefWithoutKeyListeners(model, from, to, getter);
  return getter;
}

/**
 * Generates a function that is assigned to data.$deref
 * @param {Number} len
 * @param {Number} i
 * @param {String} path
 * @param {String} currPath
 * @param {Boolean} hardLink
 * @return {Function}
 */
function derefFn (len, i, path, currPath, hardLink) {
  if (hardLink) return function () {
    return currPath;
  };
  return function (method) {
    return (i === len && method in Model.basicMutator) ? path : currPath;
  };
}

/**
 * Returns a getter function that is assigned to the ref's `from` path. When a
 * lookup function encounters the getter, it invokes the getter in order to
 * navigate to the proper node in `data` that is pointed to by the ref. The
 * invocation also "expands" the current path to the absolute path pointed to
 * by the ref.
 *
 * @param {String} to path
 * @param {String} key path
 * @param {Boolean} hardLink
 * @return {Function} getter
 */
function createGetterWithKey (to, key, hardLink) {
  /**
   * @param {Function} lookup as defined in Memory.js
   * @param {Object} data is all data in the Model or the spec model
   * @param {String} path is the path traversed so far to the ref function
   * @param {[String]} props is the array of all properties that we want to traverse
   * @param {Number} len is the number of properties in props
   * @param {Number} i is the index in props representing the current property
   * we are at in our traversal of props
   * @return {[Object, String, Number]} [current node in data, current path,
   * current props index]
   */
  return function getter (lookup, data, path, props, len, i) {
    // Here, lookup(to, data) is called in order for derefPath to work because
    // derefPath looks for data.$deref, which is lazily re-assigned on a lookup
    var obj = lookup(to, data)
      , dereffedPath = derefPath(data, to);

    // Unset $deref
    data.$deref = null;

    var pointer = lookup(key, data);
    if (Array.isArray(obj)) {
      dereffedPath += '.' + indexOf(obj, pointer, equivId);
    } else if (!obj || obj.constructor === Object) {
      dereffedPath += '.' + pointer;
    }
    var curr = lookup(dereffedPath, data)
      , currPath = joinPaths(dereffedPath, props.slice(i));

    // Reset $deref
    data.$deref = derefFn(len, i, path, currPath, hardLink);

    return [curr, currPath, i];
  }
}

function setupRefWithKeyListeners (model, from, to, key, getter) {
  var listeners = [];
  addListener(listeners, model, from, getter, to + '.*', function (match) {
    var keyPath = model.get(key) + '' // Cast to string
      , remainder = match[1];
    if (remainder === keyPath) return from;
    // Test to see if the remainder starts with the keyPath
    var index = keyPath.length;
    if (remainder.substring(0, index + 1) === keyPath + '.') {
      remainder = remainder.substring(index + 1, remainder.length);
      return from + '.' + remainder;
    }
    // Don't emit another event if the keyPath is not matched
    return null;
  });

  addListener(listeners, model, from, getter, key, function (match, mutator, args) {
    var docs = model.get(to)
      , id, out;
    if (mutator === 'set') {
      id = args[1];
      out = args.out;
      if (Array.isArray(docs)) {
        args[1] = docs && docs[ indexOf(docs, id, equivId) ];
        args.out = docs && docs[ indexOf(docs, out, equivId) ];
      } else {
        // model.get is used in case this points to a ref
        args[1] = model.get(to + '.' + id);
        args.out = model.get(to + '.' + out);
      }
    } else if (mutator === 'del') {
      if (Array.isArray(docs)) {
        args.out = docs && docs[ indexOf(docs, out, equivId) ];
      } else {
        // model.get is used in case this points to a ref
        args.out = model.get(to + '.' + out);
      }
    }
    return from;
  });
}

function equivId (id, doc) {
  return doc && doc.id === id;
}

function createGetterWithoutKey (to, hardLink) {
  // TODO Bleeding abstraction - This is very much coupled to Memory's implementation and internals.
  return function getter (lookup, data, path, props, len, i) {
    var curr = lookup(to, data)
      , dereffedPath = derefPath(data, to)
      , currPath = joinPaths(dereffedPath, props.slice(i));

    data.$deref = derefFn(len, i, path, currPath, hardLink);

    return [curr, currPath, i];
  };
}

function setupRefWithoutKeyListeners(model, from, to, getter) {
  var listeners = []
    , parents = regExpPathOrParent(to, 1)

  addListener(listeners, model, from, getter, to + '.*', function (match) {
    return from + '.' + match[1];
  });

  addListener(listeners, model, from, getter, to, function () {
    return from;
  });

  addListener(listeners, model, from, getter, parents, function (match, mutator, args) {
    var path = match.input
      , remainder = to.slice(path.length + 1)

    if (mutator === 'set') {
      args[1] = lookup(remainder, args[1]);
      args.out = lookup(remainder, args.out);
    } else if (mutator === 'del') {
      args.out = lookup(remainder, args.out);
    } else {
      // Don't emit an event if not a set or delete
      return null;
    }
    return from;
  });
}
