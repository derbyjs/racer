var refUtils = require('./util')
  , RefListener = refUtils.RefListener
  , pathUtil = require('../path')
  , regExpPathOrParent = pathUtil.regExpPathOrParent
  , lookup = pathUtil.lookup
  , indexOf = require('../util').indexOf
  , indexOfFn = require('../util').indexOfFn
  , Model = require('../Model')
  , treeLookup = require('../tree').lookup
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
  } else {
    var getter = createGetterWithoutKey(to, hardLink);
    setupRefWithoutKeyListeners(model, from, to, getter);
  }
  return getter;
}

// TODO Rewrite *WithKey to work
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
  return function getterWithKey (data, pathToRef, rest, meta) {
    var toOut          = treeLookup(data, to, null)
      , domain         = toOut.node
      , dereffedToPath = toOut.path

      , keyOut          = treeLookup(data, key, null)
      , id              = keyOut.node
      , path, node

    if (Array.isArray(domain)) {
      var index = indexOfFn(domain, function (doc) {
        return doc.id === id;
      });
      node = domain[index];
      path = dereffedToPath + '.' + index;
    } else if (! domain) {
      node = undefined;
      path = dereffedToPath + '.' + id;
    } else if (domain.constructor === Object) {
      node = domain[id];
      path = dereffedToPath + '.' + id;
    } else {
      throw new Error();
    }
    if (meta.refEmitter) {
      meta.refEmitter.onRef(node, path, rest, hardLink);
    }
    return {node: node, path: path};
  }
}

function setupRefWithKeyListeners (model, from, to, key, getter) {
  var refListener = new RefListener(model, from, getter)
    , toOffset = to.length + 1;

  refListener.add(to + '.*', function (path) {
    var keyPath = model.get(key) + '' // Cast to string
      , remainder = path.slice(toOffset);
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

  refListener.add(key, function (path, mutator, args) {
    var docs = model.get(to)
      , id
      , out = args.out
      ;
    if (mutator === 'set') {
      id = args[1];
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
  return function getterWithoutKey (data, pathToRef, rest, meta) {
    var prevRests = meta.prevRests || []
    prevRests.unshift(rest);
    var out = treeLookup(data, to, {prevRests: prevRests});
    prevRests.shift();
    if (meta.refEmitter) {
      meta.refEmitter.onRef(out.node, out.path, rest, hardLink);
    }
    return out;
  };
}

function setupRefWithoutKeyListeners(model, from, to, getter) {
  var refListener = new RefListener(model, from, getter)
    , toOffset = to.length + 1;

  refListener.add(to, function () {
    return from;
  });

  refListener.add(to + '.*', function (path) {
    return from + '.' + path.slice(toOffset);
  });

  refListener.add(regExpPathOrParent(to, 1), function (path, mutator, args) {
    var remainder = to.slice(path.length + 1)

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
