var pathUtils = require('../path')
  , isPrivate = pathUtils.isPrivate
  , eventRegExp = pathUtils.eventRegExp;

module.exports = {
  // TODO This is a horribly named function.
  //
  // $deref is invoked in:
  // - via derefPath in refs/util.js
  // - refs/index.js in the 'beforeTxn' callback.
  derefPath: function (data, to) {
    return data.$deref ? data.$deref() : to;
  }

, addListener: addListener

  /**
   * Asserts that the path of a ref is private.
   * @param {String} from is the path of the ref
   * @param {String} refType is either 'ref' or 'refList'
   */
, assertPrivateRefPath: function (model, path, refType) {
    if (! isPrivate(model.dereference(path, true)) )
      throw new Error('Cannot create ' + refType + ' on public path "' + from + '"');
  }
};


/**
 * Add a listener function (method, path, arguments) on the 'mutator' event.
 * The listener ignores mutator events that fire on paths that do not match
 * `pattern`
 * @param {Model} model is the model we are adding the listener to
 * @param {String} from is the private path of the ref
 * @param {Function} getter
 * @param {String} pattern
 * @param {Function} generatePath(match, mutator, args)
 */
function addListener (listeners, model, from, getter, pattern, generatePath) {
  var regexp = eventRegExp(pattern);
  function listener (mutator, _arguments) {
    var path = _arguments[0][0];
    if (! regexp.test(path)) return;

    // Lazy cleanup of listener
    if (model._getRef(from) !== getter) {
      for (var i = listeners.length; i --; ) {
        model.removeListener('mutator', listeners[i]);
      }
      return;
    }

    // Construct the next de-referenced path to emit on. generagePath may also
    // alter args = _arguments[0].slice()
    var args = _arguments[0].slice();
    args.out = _arguments[1];
    var dereffedPath = generatePath(regexp.exec(path), mutator, args);
    if (dereffedPath === null) return;
    args[0] = dereffedPath;
    var isLocal = _arguments[2]
      , pass    = _arguments[3];
    model.emit(mutator, args, args.out, isLocal, pass);
  }
  listeners.push(listener);

  model.on('mutator', listener);
}
