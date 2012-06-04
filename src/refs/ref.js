var refUtils = require('./util')
  , derefPath = refUtils.derefPath
  , addListener = refUtils.addListener
  , joinPaths = require('../path').join
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
  if (hardLink) return function () { return currPath; };
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
   * @param {String} path is the path traversed so far
   * @param {[String]} props is the array of all properties that we want to traverse
   * @param {Number} len is the number of properties in props
   * @param {Number} i is the index in props representing the current property
   * we are at in our traversal of props
   * @return {[Object, String, Number]} [current node in data, current path,
   * current props index]
   */
  return function getter (lookup, data, path, props, len, i) {
    lookup(to, data);
    var dereffedPath = derefPath(data, to);

    // Unset $deref
    data.$deref = null;

    dereffedPath += '.' + lookup(key, data);
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
    if (mutator === 'set') {
      args[1] = model.get(to + '.' + args[1]);
      args.out = model.get(to + '.' + args.out);
    } else if (mutator === 'del') {
      args.out = model.get(to + '.' + args.out);
    }
    return from;
  });
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
  var listeners = [];
  addListener(listeners, model, from, getter, to + '.*', function (match) {
    return from + '.' + match[1];
  });

  addListener(listeners, model, from, getter, to, function () {
    return from;
  });
}
