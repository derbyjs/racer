var pathUtils = require('../path')
  , joinPaths = pathUtils.join
  , isPrivate = pathUtils.isPrivate
  , eventRegExp = pathUtils.eventRegExp
  , utils = require('../util')
  , hasKeys = utils.hasKeys

module.exports = {
  assertPrivateRefPath: assertPrivateRefPath
, RefListener: RefListener
, RefEmitter: RefEmitter
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
 * @param {Function} generatePath(match, mutator, args) generates the referenced
 *   (i.e., inverse of de-referenced) path. This path is used to generate a
 *   path that we should emit on for this reference.
 */
function RefListener(model, from, getter) {
  var patternRegExps = this.patternRegExps = []
    , pathGenerators = this.pathGenerators = []

  var listener = function listenerRefMutator (mutator, _arguments) {
    var path = _arguments[0][0]
      , matches, i
      ;
    for (i = patternRegExps.length; i--;) {
      if (patternRegExps[i].test(path)) {
        (matches || (matches = [])).push(i);
      }
    }
    // Lazy cleanup of listener
    if (!matches || cleanup()) return;

    var pathGenerator, args, dereffedPath, isLocal, pass;
    for (i = matches.length; i--;) {
      pathGenerator = pathGenerators[matches[i]];
      // Construct the next de-referenced path to emit on. pathGenerator
      // may also alter args
      args = _arguments[0].slice();
      args.out = _arguments[1];
      dereffedPath = pathGenerator(path, mutator, args);
      if (dereffedPath === null) continue;
      args[0] = dereffedPath;
      isLocal = _arguments[2];
      pass = _arguments[3];
      model.emit(mutator, args, args.out, isLocal, pass);
    }
  };

  function cleanup() {
    if (model._getRef(from) === getter) return;
    model.removeListener('mutator', listener);
    model.removeListener('cleanup', cleanup);
    return true;
  }
  model.on('cleanup', cleanup);

  model.on('mutator', listener);
}

/**
 * @param {String} pattern
 * @param {Function} pathGenerator(path, method, args)
 */
RefListener.prototype.add = function (pattern, pathGenerator) {
  this.patternRegExps.push(eventRegExp(pattern));
  this.pathGenerators.push(pathGenerator);
}

function RefEmitter(model, method, args) {
  this.model = model;
  this.method = method;
  this.args = args;
}

/**
 * Called when a lookup gets to a refList.
 * Changes this.args.
 * May also set dereffed + '.' + id
 *
 * @param {Array<Object>} node
 * @param {String} pathToRef is the path to the refList
 * @param {Array<String>} rest is the rest of the properties we want to look
 *   up, after encountering the refList. Should be empty.
 * @param {Array<String>} pointerList is an array of other document ids
 * @param {String} dereffed is the dereferenced path to the refList
 * @param {String} pathToPointerList is the dereferneced path to the refList list of pointers
 */
RefEmitter.prototype.onRefList = function (node, pathToRef, rest, pointerList, dereffed, pathToPointerList) {
  var id;
  if (rest.length) return;
  var Model = this.model.constructor
    , basicMutators = Model.basicMutator;

  // This function should handle array mutations only
  if (!this.method || (this.method in basicMutators)) return;

  var arrayMutators = Model.arrayMutator
    , mutator = arrayMutators[this.method];
  if (!mutator) throw new Error(this.method + ' unsupported on refList');

  this.args[0] = pathToPointerList;

  var j, arg, indexArgs;
  // Handle index args if they are specified by id
  if (indexArgs = mutator.indexArgs) {
    for (var k = 0, len = indexArgs.length; k < len; k++) {
      j = indexArgs[k];
      arg = this.args[j];
      if (!arg) continue;
      id = arg.id;
      if (id == null) continue;
      // Replace id arg with the current index for the given id
      var idIndex = pointerList.indexOf(id);
      if (idIndex !== -1) this.args[j] = idIndex;
    }
  }

  if (j = mutator.insertArgs) {
    while (arg = this.args[j]) {
      id = (arg.id == null) ? (arg.id = this.model.id()) : arg.id;
      // Set the object being inserted if it contains any properties
      // other than id
      if (hasKeys(arg, 'id')) {
        this.model.set(dereffed + '.' + id, arg);
      }
      this.args[j] = id;
      j++;
    }
  }
};

/**
 * @param {Array<Object>} node
 * @param {Array<String>} pointerList
 * @param {String} memberKeyPath
 * @param {String} domainPath
 * @param {String} id
 * @param {Array<String>} rest
 */
RefEmitter.prototype.onRefListMember = function (node, pointerList, memberKeyPath, domainPath, id, rest) {
  // TODO Additional model methods should be done atomically with the
  // original txn instead of making an additional txn
  var method = this.method;
  if (method === 'set') {
    var model = this.model;
    var origSetTo = this.args[1];
    if (!id) {
      id = (origSetTo.id != null)
         ? origSetTo.id
         : (origSetTo.id = model.id());
    }
    if (model.get(memberKeyPath) !== id) {
      model.set(memberKeyPath, id);
    }
    this.args[0] = joinPaths(domainPath, id, rest);
  } else if (method === 'del') {
    id = node.id;
    if (id == null) {
      throw new Error('Cannot delete refList item without id');
    }
    if (! rest.length) {
      this.model.del(memberKeyPath);
    }
    this.args[0] = joinPaths(domainPath, id, rest);
  } else if (rest.length) {
    this.args[0] = joinPaths(domainPath, id, rest);
  } else {
    throw new Error(method + ' unsupported on refList index');
  }
};

RefEmitter.prototype.onRef = function (node, dereffedToPath, rest, hardLink) {
  // Allow ref to be deleted or over-written if not a hardLink
  if (!hardLink && !rest.length && (this.method === 'del' || this.method == 'set')) return;
  this.args[0] = joinPaths(dereffedToPath, rest);
};
