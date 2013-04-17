var EventEmitter = require('events').EventEmitter;
var racer = require('../racer');
var util = require('../util');
var eventRegExp = require('../util/path').eventRegExp;
var Model = require('./index');

racer.on('Model:init', function(model) {
  // Set max listeners to unlimited
  model.setMaxListeners(0);

  var cleanupCounts = 0;
  var cleaning = false;
  model.on('newListener', function(name) {
    if (name !== 'cleanup') return;
    if (cleanupCounts++ < 128) return;
    cleanupCounts = 0;
    if (cleaning) return;
    cleaning = true;
    setTimeout(function() {
      model.emit('cleanup');
      cleaning = false;
    }, 10);
  });
});

util.merge(Model.prototype, EventEmitter.prototype);

// EventEmitter.prototype.on, EventEmitter.prototype.addListener, and
// EventEmitter.prototype.once return `this`. The Model equivalents return
// the listener instead, since it is made internally for method subscriptions
// and may need to be passed to removeListener.

Model.prototype._on = EventEmitter.prototype.on;
Model.prototype.addListener =
Model.prototype.on = function(type, pattern, callback) {
  var listener = eventListener(this, type, pattern, callback);
  this._on(type, listener);
  // The `event` property is added to the function to simplify implementing
  // custom cleanup logic that iterates through listeners and removes them
  listener.event = type;
  return listener;
};

Model.prototype.once = function(type, pattern, callback) {
  var listener = eventListener(this, type, pattern, callback);
  function g() {
    var matches = listener.apply(null, arguments);
    if (matches) this.removeListener(type, g);
  }
  this._on(type, g);
  return g;
};

Model.prototype._removeAllListeners = EventEmitter.prototype.removeAllListeners;
Model.prototype.removeAllListeners = function(type, subpath) {
  if (!this._events) return this;

  path = this.path(subpath);
  // If no path is specified, remove all listeners like normal
  if (!path) {
    if (arguments.length === 0) {
      return this._removeAllListeners();
    } else {
      return this._removeAllListeners(type);
    }
  }

  // If a path is specified without an event type, remove all model event
  // listeners under that path for all events
  if (!type) {
    for (key in this._events) {
      this.removeAllListeners(key, subpath);
    }
    return this;
  }

  // Remove all listeners for an event under a path
  var listeners = this.listeners(type);
  var segments = path.split('.');
  // Make sure to iterate in reverse, since the array might be
  // mutated as listeners are removed
  for (var i = listeners.length; i--;) {
    if (patternContained(segments, listener.patternSegments)) {
      this.removeListener(type, listener);
    }
  }
}

function patternContained(segments, patternSegments) {
  var len = segments.length;
  if (!patternSegments || len > patternSegments.length) return false;
  for (var i = 0; i < len; i++) {
    var segment = segments[i];
    var patternSegment = patternSegments[i];
    if (segment !== patternSegment && patternSegment !== '*') return false;
  }
  return true;
}

/**
 * Used to pass an additional argument to local events.
 *
 * @param {Object} arg
 * @return {Model} an Object that prototypically inherits from the calling
 * Model instance, but with a _pass attribute equivalent to `arg`.
 * @api public
 */
Model.prototype.pass = function(arg) {
  return Object.create(this, {_pass: {value: arg}});
};

Model.prototype.silent = function() {
  return Object.create(this, {_silent: {value: true}});
};

/**
 * Returns a function that is assigned as an event listener on model events
 * such as 'change' and 'insert'
 *
 * @param {String} method
 * @param {String} pattern
 * @param {Function} callback
 * @param {String} at
 * @return {Function} function ([path, args...], out, isLocal, pass)
 */
function eventListener(model, pattern, cb) {
  if (cb) {
    // For signatures:
    // model.on('change', 'example.subpath', callback)
    // model.at('example').on('change', 'subpath', callback)
    pattern = model.path(pattern);
    return modelEventListener(pattern, cb);
  }
  var path = model.path();
  // For signature:
  // model.at('example').on('change', callback)
  if (path) return modelEventListener(path, pattern);
  // For signature:
  // model.on('normalEvent', callback)
  return pattern;
}

function modelEventListener(pattern, cb) {
  var patternSegments = pattern.split('.');
  var testFn = testPatternFn(patternSegments);

  function modelListener(segments, args) {
    var captures = testFn(segments);
    if (!captures) return;

    cb.apply(null, captures.concat(args));
    return true;
  }

  // Used to remove all model listeners under a path
  modelListener.patternSegments = patternSegments;

  return modelListener;
}

function testPatternFn(patternSegments) {
  // Check to see if the pattern ends in a wildcard, such as
  // example.subpath.* or example.subpath*
  var patternLen = patternSegments.length;
  var lastIndex = patternLen - 1;
  var last = patternSegments[lastIndex];
  var endingWildcard = last.charAt(last.length - 1) === '*';
  // ['example', 'subpath*'] -> ['example', 'subpath']
  if (endingWildcard && last.length > 1) {
    patternSegments[lastIndex] = last.slice(0, -1);
  }

  return function testPattern(segments) {
    // Any pattern with more segments does not match
    if (patternLen > segments.length) return;

    // A pattern with the same number of segments matches if each
    // of the segments are wildcards or equal
    if (patternLen === segments.length) {
      var captures = [];
      for (var i = 0; i < patternLen; i++) {
        var patternSegment = patternSegments[i];
        var segment = segments[i];
        if (patternSegment === '*') {
          captures.push(segment);
          continue;
        }
        if (patternSegment !== segment) return;
      }
      return captures;
    }

    // A shorter pattern matches if it ends in a wildcard and each
    // of the corresponding segments are wildcards or equal
    if (endingWildcard) {
      var captures = [];
      for (var i = 0; i < patternLen; i++) {
        var patternSegment = patternSegments[i];
        var segment = segments[i];
        if (patternSegment === '*') {
          if (i === lastIndex) {
            var remainder = segments.slice(i).join('.');
            captures.push(remainder);
            return captures;
          }
          captures.push(segment);
          continue;
        }
        if (patternSegment !== segment) return;
      }
      var remainder = segments.slice(i).join('.');
      captures.push(remainder);
      return captures;
    }
  }
}
