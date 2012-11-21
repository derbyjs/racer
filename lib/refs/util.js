var pathUtils = require('../path')
  , joinPaths = pathUtils.join
  , isPrivate = pathUtils.isPrivate
  , eventRegExp = pathUtils.eventRegExp
  , utils = require('../util')
  , hasKeys = utils.hasKeys
  , EventEmitter = require('events').EventEmitter

module.exports = {
  addListener: addListener
, assertPrivateRefPath: assertPrivateRefPath
, createRefEmitter: createRefEmitter
};

/**
 * Asserts that the path of a ref is private.
 * @param {Model} model
 * @param {String} path is the path of the ref
 */
function assertPrivateRefPath(model, path) {
  if (! isPrivate(model.dereference(path, true)) )
    throw new Error('Cannot create ref on public path "' + path + '"');
}

/**
 * Add a listener function (method, path, arguments) on the 'mutator' event.
 * The listener ignores mutator events that fire on paths that do not match
 * `pattern`
 * @param {Array} listeners is an Array of listener functions that the listener
 * we generate is added to.
 * @param {Model} model is the model to which we add the listener
 * @param {String} from is the private path of the ref
 * @param {Function} getter
 * @param {String} pattern
 * @param {Function} generatePath(match, mutator, args)
 */
function addListener (listeners, model, from, getter, pattern, generatePath) {
  var regexp = eventRegExp(pattern);
  function listener (mutator, _arguments) {
    var path = _arguments[0][0];
    if (!regexp.test(path)) return;

    // Lazy cleanup of listener
    if (model._getRef(from) !== getter) {
      for (var i = listeners.length; i--;) {
        model.removeListener('mutator', listeners[i]);
      }
      return;
    }

    // Construct the next de-referenced path to emit on. generatePath may also
    // alter args = _arguments[0].slice()
    var args = _arguments[0].slice();
    args.out = _arguments[1];
    var dereffedPath = generatePath(regexp.exec(path), mutator, args);
    if (dereffedPath === null) return;
    args[0] = dereffedPath;
    var isLocal = _arguments[2]
      , pass = _arguments[3];
    model.emit(mutator, args, args.out, isLocal, pass);
  }
  listeners.push(listener);

  model.on('mutator', listener);
}


function createRefEmitter(model, method, args) {
  var Model = model.constructor
    , refEmitter = new EventEmitter();

  refEmitter.on('refList', function (node, pathToRef, rest, pointerList, dereffed, pathToPointerList) {
    var id;
    if (!rest.length) {
      var basicMutators = Model.basicMutator;
      if (!method || (method in basicMutators)) return;

      var arrayMutators = Model.arrayMutator
        , mutator = arrayMutators[method];
      if (!mutator) throw new Error(method + ' unsupported on refList');

      args[0] = pathToPointerList;

      var j, arg, indexArgs;
      // Handle index args if they are specified by id
      if (indexArgs = mutator.indexArgs) {
        for (var k = 0, len = indexArgs.length; k < len; k++) {
          j = indexArgs[k];
          arg = args[j];
          if (!arg) continue;
          id = arg.id;
          if (id == null) continue;
          // Replace id arg with the current index for the given id
          var idIndex = pointerList.indexOf(id);
          if (idIndex !== -1) args[j] = idIndex;
        }
      }

      if (j = mutator.insertArgs) {
        while (arg = args[j]) {
          id = (arg.id == null) ? (arg.id = model.id()) : arg.id;
          // Set the object being inserted if it contains any properties
          // other than id
          if (hasKeys(arg, 'id')) {
            model.set(dereffed + '.' + id, arg);
          }
          args[j] = id;
          j++;
        }
      }
    }
  });
  refEmitter.on('refListMember', function (node, pointerList, memberKeyPath, domainPath, id, rest) {
    // TODO Additional model methods should be done atomically with the
    // original txn instead of making an additional txn
    if (method === 'set') {
      var origSetTo = args[1];
      if (!id) {
        id = (origSetTo.id != null)
           ? origSetTo.id
           : (origSetTo.id = model.id());
      }
      model.set(memberKeyPath, id);
      args[0] = joinPaths(domainPath, id, rest);
    } else if (method === 'del') {
      id = node.id;
      if (id == null) {
        throw new Error('Cannot delete refList item without id');
      }
      if (! rest.length) {
        model.del(memberKeyPath);
      }
      args[0] = joinPaths(domainPath, id, rest);
    } else if (rest.length) {
      args[0] = joinPaths(domainPath, id, rest);
    } else {
      throw new Error(method + ' unsupported on refList index');
    }
  });

  refEmitter.on('refWithKey', function (node, dereffedToPath, id, rest, hardLink) {
    var dereffedRefPath = dereffedToPath + '.' + id;
    if (hardLink || ! ( // unless we're a hardLink or...
      !rest.length && method === 'del' // ...deleting a ref
    )) {
      args[0] = joinPaths(dereffedRefPath, rest);
    }
  });
  refEmitter.on('refWithoutKey', function (node, dereffedToPath, rest, hardLink) {
    if (hardLink || ! ( // unless we're a hardLink or...
      !rest.length && (method === 'del' || method == 'set') // ...deleting or over-writing a ref
    )) {
      args[0] = joinPaths(dereffedToPath, rest);
    }
  });
  return refEmitter;
}
