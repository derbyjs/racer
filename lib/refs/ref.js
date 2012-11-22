var refUtils = require('./util')
  , addListener = refUtils.addListener
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
    return getter;
  }
  var getter = createGetterWithoutKey(to, hardLink);
  setupRefWithoutKeyListeners(model, from, to, getter);
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
  return function getter (data, pathToRef, rest, refEmitter) {
    var toOut          = treeLookup(data, to, null)
      , domain         = toOut.node
      , dereffedToPath = toOut.path

      , keyOut          = treeLookup(data, key, null)
      , id              = keyOut.node
      , out
      ;

    if (Array.isArray(domain)) {
      var index = indexOfFn(domain, function (doc) {
        return doc.id === id;
      });
      out = {
        path: dereffedToPath + '.' + index
      , node: domain[index]
      }
    } else if (! domain) {
      out = {
        path: dereffedToPath + '.' + id
      , node: undefined
      }
    } else if (domain.constructor === Object) {
      out = {
        path: dereffedToPath + '.' + id
      , node: domain[id]
      }
    } else {
      throw new Error();
    }
    if (typeof out.node === 'undefined') out.halt = true;
    refEmitter && refEmitter.emit('refWithKey', out.node, dereffedToPath, id, rest, hardLink);
    return out;
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
  return function getter (data, pathToRef, rest, refEmitter, prevRests) {
    if (! prevRests) {
      prevRests = [rest];
    } else {
      prevRests.push(rest);
    }
    var out = treeLookup(data, to, {prevRests: prevRests});
    prevRests.pop();
    refEmitter && refEmitter.emit('refWithoutKey', out.node, out.path, rest, hardLink);
    if (typeof out.node === 'undefined') out.halt = true;
    return out;
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
