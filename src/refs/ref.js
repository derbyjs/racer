var eventRegExp = require('../path').eventRegExp
  , refUtils = require('./util')
  , derefPath = refUtils.derefPath
  , lookupPath = refUtils.lookupPath
  , Model = require('../Model')
  ;

exports = module.exports = createRef;

function createRef (model, from, to, key, hardLink) {
  if (!from) {
    throw new Error('Missing `from` in `model.ref(from, to, key)`');
  }
  if (!to) {
    throw new Error('Missing `to` in `model.ref(from, to, key)`');
  }

  if (key) return setupRefWithKey(model, from, to, key, hardLink);
  return setupRefWithoutKey(model, from, to, hardLink);
}

exports.addListener = addListener;

function derefFn (len, i, path, currPath, hardLink) {
  if (hardLink) return function () { return currPath; };
  return function (method) {
    return (i === len && method in Model.basicMutator) ? path : currPath;
  };
}

function setupRefWithKey (model, from, to, key, hardLink) {
  var listeners = [];

  function getter (lookup, data, path, props, len, i) {
    lookup(to, data);
    var dereffed = derefPath(data, to) + '.';
    data.$deref = null;
    dereffed += lookup(key, data);
    var curr = lookup(dereffed, data)
      , currPath = lookupPath(dereffed, props, i);
    data.$deref = derefFn(len, i, path, currPath, hardLink);
    return [curr, currPath, i];
  }

  addListener(model, from, getter, listeners, to + '.*', function (match) {
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

  addListener(model, from, getter, listeners, key, function (match, mutator, args) {
    if (mutator === 'set') {
      args[1] = model.get(to + '.' + args[1]);
      args.out = model.get(to + '.' + args.out);
    } else if (mutator === 'del') {
      args.out = model.get(to + '.' + args.out);
    }
    return from;
  });

  return getter;
}

function setupRefWithoutKey (model, from, to, hardLink) {
  var listeners = [];

  function getter (lookup, data, path, props, len, i) {
    var curr = lookup(to, data)
      , dereffed = derefPath(data, to)
      , currPath = lookupPath(dereffed, props, i);

    data.$deref = derefFn(len, i, path, currPath, hardLink);

    return [curr, currPath, i];
  }

  addListener(model, from, getter, listeners, to + '.*', function (match) {
    return from + '.' + match[1];
  });

  addListener(model, from, getter, listeners, to, function () {
    return from;
  });

  return getter;
}

/**
 * Add a listener function (method, path, arguments) on the 'mutator' event.
 * The listener ignores mutator events that fire on paths that do not match
 * `pattern`
 * @param {Model} model is the model we are adding the listener to
 * @param {String} from is the private path of the ref
 * @param {Function} getter
 * @param {String} pattern
 * @param {Function} callback(match, mutator, args)
 */
function addListener (model, from, getter, listeners, pattern, callback) {
  var re = eventRegExp(pattern);
  function listener (mutator, path, _arguments) {
    if (! re.test(path)) return;

    // Lazy cleanup of listeners
    if (model._getRef(from) !== getter) {
      for (var i = listeners.length; i--; ) {
        model.removeListener('mutator', listeners[i]);
      }
      return;
    }

    var args = _arguments[0].slice();
    args.out = _arguments[1];
    var path = callback(re.exec(path), mutator, args);
    if (path === null) return;
    args[0] = path;
    model.emit(mutator, args, args.out, _arguments[2], _arguments[3]);
  }

  listeners.push(listener);
  model.on('mutator', listener);
}
