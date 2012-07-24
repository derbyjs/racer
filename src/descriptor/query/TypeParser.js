var EventEmitter = require('events').EventEmitter;

module.exports = TypeParser;

function Classifier () {
  this.detectors = [];
}

Classifier.prototype.classify = function (x) {
}

Classifier.prototype.klass = function (klass, detect) {
  this.detectors.push([detect, klass]);
  return this;
}

var classifier = new Classifier;
classifier.klass(
  function (x) {
    return Array.isArray(x) || x.tuple;
  }
);

function TypeParser () {
  EventEmitter.call(this);
  this.handlers = this.handlers.slice();
}

TypeParser.prototype = new EventEmitter();

TypeParser.prototype.handlers = [];

TypeParser.prototype.handle = function (dispatch, callback) {
  this.handlers.push([dispatch, callback]);
};

TypeParser.prototype.parse = function (targets) {
  var handlers = this.handlers;
  for (var i = 0, l = targets.length; i < l; i++) {
    var targ = targets[i];
    var handled = elsif(handlers, targ, this);
    if (! handled) {
      this.emit('unhandled', targ);
    }
  }
  this.emit('done');
};

TypeParser.prototype.handle(
  function (x) {
    if (Array.isArray(x)) return 'query';
    if (x.tuple) return 'query';
  }
, function (query, parser) {
    parser.emit('query', query.tuple);
  }
);

TypeParser.prototype.typeFn(
  function (x) {
    if (typeof x === 'string') return 'pattern';
  }
, function (pattern, parser) {
    parser.emit('pattern', pattern);
    var paths = expandPath(target);
    for (var i = paths.length; i--; ) {
      parser.emit('path', paths[i]);
    }
  }
);

function elsif (ifThens, target, parser) {
  for (var i = 0, l = ifThens.length; i < l; i++) {
    var ifThen = ifThens[i]
      , ifFn   = ifThen[0]
      , thenFn = ifThen[1];
    if (ifFn(target)) {
      thenFn(target, parser);
      return true;
    }
  }
  return false;
}
