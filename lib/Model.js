var EventEmitter = require('events').EventEmitter
  , eventRegExp = require('./path').eventRegExp
  , mergeAll = require('./util').mergeAll
  , uuid = require('node-uuid')

module.exports = Model;

function Model() {
  this.flags || (this.flags = {});
  // Set max listeners to unlimited
  this.setMaxListeners(0);

  var cleanupCounts = 0
    , self = this
    , cleaning = false;
  this.on('newListener', function(name) {
    if (name !== 'cleanup') return;
    if (cleanupCounts++ < 128) return;
    cleanupCounts = 0;
    if (cleaning) return;
    cleaning = true;
    setTimeout(function() {
      self.emit('cleanup');
      cleaning = false;
    }, 10);
  });

  // Used for model scopes
  this._root = this;
  this.mixinEmit('init', this);
}

var modelProto = Model.prototype
  , emitterProto = EventEmitter.prototype;

mergeAll(modelProto, emitterProto, {
  id: function () {
    return uuid.v4();
  }

  /* Scoped Models */

  /**
   * Create a model object scoped to a particular path.
   * Example:
   *     var user = model.at('users.1');
   *     user.set('username', 'brian');
   *     user.on('push', 'todos', function (todo) {
   *       // ...
   *     });
   *
   *  @param {String} segment
   *  @param {Boolean} absolute
   *  @return {Model} a scoped model
   *  @api public
   */
, at: function (segment, absolute) {
    var at = this._at
      , val = (at && !absolute)
            ? (segment === '')
              ? at
              : at + '.' + segment
            : segment.toString()
    return Object.create(this, { _at: { value: val } });
  }

, root: function () {
    return Object.create(this, { _at: { value: null } });
  }

  /**
   * Returns a model scope that is a number of levels above the current scoped
   * path. Number of levels defaults to 1, so this method called without
   * arguments returns the model scope's parent model scope.
   *
   * @optional @param {Number} levels
   * @return {Model} a scoped model
   */
, parent: function (levels) {
    if (! levels) levels = 1;
    var at = this._at;
    if (!at) return this;
    var segments = at.split('.');
    return this.at(segments.slice(0, segments.length - levels).join('.'), true);
  }

  /**
   * Returns the path equivalent to the path of the current scoped model plus
   * the suffix path `rest`
   *
   * @optional @param {String} rest
   * @return {String} absolute path
   * @api public
   */
, path: function (rest) {
    var at = this._at;
    if (at) {
      if (rest) return at + '.' + rest;
      return at;
    }
    return rest || '';
  }

  /**
   * Returns the last property segment of the current model scope path
   *
   * @optional @param {String} path
   * @return {String}
   */
, leaf: function (path) {
    if (!path) path = this._at || '';
    var i = path.lastIndexOf('.');
    return path.substr(i+1);
  }

  /* Model events */

  // EventEmitter.prototype.on, EventEmitter.prototype.addListener, and
  // EventEmitter.prototype.once return `this`. The Model equivalents return
  // the listener instead, since it is made internally for method subscriptions
  // and may need to be passed to removeListener.

, _on: emitterProto.on
, on: function (type, pattern, callback) {
    var self = this
      , listener = eventListener(type, pattern, callback, this);
    this._on(type, listener);
    listener.cleanup = function () {
      self.removeListener(type, listener);
    }
    return listener;
  }

, _once: emitterProto.once
, once: function (type, pattern, callback) {
    var listener = eventListener(type, pattern, callback, this)
      , self;
    this._on( type, function g () {
      var matches = listener.apply(null, arguments);
      if (matches) this.removeListener(type, g);
    });
    return listener;
  }

  /**
   * Used to pass an additional argument to local events. This value is added
   * to the event arguments in txns/mixin.Model
   * Example:
   *     model.pass({ ignore: domId }).move('arr', 0, 2);
   *
   * @param {Object} arg
   * @return {Model} an Object that prototypically inherits from the calling
   * Model instance, but with a _pass attribute equivalent to `arg`.
   * @api public
   */
, pass: function (arg) {
    return Object.create(this, { _pass: { value: arg } });
  }

, silent: function () {
    return Object.create(this, { _silent: { value: true } });
  }
});

modelProto.addListener = modelProto.on;

/**
 * Returns a function that is assigned as an event listener on method events
 * such as 'set', 'insert', etc.
 *
 * Possible function signatures are:
 *
 * - eventListener(method, pattern, callback, at)
 * - eventListener(method, pattern, callback)
 * - eventListener(method, callback)
 *
 * @param {String} method
 * @param {String} pattern
 * @param {Function} callback
 * @param {String} at
 * @return {Function} function ([path, args...], out, isLocal, pass)
 */
function eventListener (method, pattern, callback, model) {
  if (model._at) {
    if (typeof pattern === 'string') {
      pattern = model._at + '.' + pattern;
    } else if (pattern.call) {
      callback = pattern;
      pattern = model._at;
    } else {
      throw new Error('Unsupported event pattern on scoped model');
    }

    // on(type, listener)
    // Test for function by looking for call, since pattern can be a RegExp,
    // which has typeof pattern === 'function' as well
  } else if ((typeof pattern === 'function') && pattern.call) {
    return pattern;
  }

  // on(method, pattern, callback)
  var regexp = eventRegExp(pattern)
    , listener

  if (method === 'mutator') {
    listener = function listenerModelMutator (mutatorMethod, _arguments) {
      var args = _arguments[0]
        , path = args[0];
      if (! regexp.test(path)) return;

      var captures = regexp.exec(path).slice(1)
        , callbackArgs = captures.concat([mutatorMethod, _arguments]);
      callback.apply(null, callbackArgs);
      return true;
    };
  } else {
    listener = function listenerModel (args, out, isLocal, pass) {
      var path = args[0];
      if (! regexp.test(path)) return;

      args = args.slice(1);
      var captures = regexp.exec(path).slice(1)
        , callbackArgs = captures.concat(args).concat([out, isLocal, pass]);
      callback.apply(null, callbackArgs);
      return true;
    };
  }

  function removeModelListener() {
    model.removeListener(method, listener);
    model.removeListener('removeModelListeners', removeModelListener);
  }
  model._on('removeModelListeners', removeModelListener);

  return listener;
}
