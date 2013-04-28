var racer = require('../racer');
var Model = require('./index');

function NamedFns() {}
Model._namedFns = new NamedFns;

// Functions are defined on the constructor so that they can
// be accessed by every model
Model.fn = function(name, fns) {
  this._namedFns[name] = fns;
};

racer.on('Model:init', function(model) {
  model._fns = new Fns(model, model.constructor._namedFns);
  model.on('all', fnListener);
  function fnListener(segments, eventArgs) {
    var pass = eventArgs[eventArgs.length - 1];
    if (pass === 'fn') return;
    var running = model._fns.runningMap;
    for (var path in running) {
      var fn = running[path];
      if (mayImpactAny(fn.inputPathsSegments, segments)) {
        // Mutation affecting input path
        fn.onInput();
      } else if (mayImpact(fn.pathSegments, segments)) {
        // Mutation affecting output path
        fn.onOutput();
      }
    }
  }
});

function mayImpactAny(segmentsList, testSegments) {
  for (var i = 0, len = segmentsList.length; i < len; i++) {
    if (mayImpact(segmentsList[i], testSegments)) return true;
  }
  return false;
}

function mayImpact(segments, testSegments) {
  for (var i = 0, len = testSegments.length; i < len; i++) {
    if (segments[i] !== testSegments[i]) return false;
  }
  return true;
}

Model.prototype.run = function(name) {
  var inputPaths = Array.prototype.slice.call(arguments, 1);
  for (var i = inputPaths.length; i--;) {
    inputPaths[i] = this.path(inputPaths[i]);
  }
  return this._fns.get(name, inputPaths);
};

Model.prototype.start = function(name, subpath) {
  var path = this.path(subpath);
  var inputPaths = Array.prototype.slice.call(arguments, 2);
  for (var i = inputPaths.length; i--;) {
    inputPaths[i] = this.path(inputPaths[i]);
  }
  return this._fns.start(name, path, inputPaths);
};

Model.prototype.stop = function(subpath) {
  var path = this.path(subpath);
  this._fns.stop(path);
};


function RunningMap() {}
function Fns(model, nameMap) {
  this.model = model;
  this.nameMap = nameMap;
  this.runningMap = new RunningMap;
}

Fns.prototype.get = function(name, inputPaths) {
  var fns = this.nameMap[name];
  if (!fns) {
    var err = new TypeError('Model function not found: ' + name);
    this.model.emit('error', err);
  }
  var fn = new Fn(this.model, null, inputPaths, fns);
  return fn.get();
};

Fns.prototype.start = function(name, path, inputPaths) {
  var fns = this.nameMap[name];
  var fn = new Fn(this.model, path, inputPaths, fns);
  fn.splitPaths();
  this.runningMap[path] = fn;
  return fn.onInput();
};

Fns.prototype.stop = function(path) {
  delete this.runningMap[path];
};

function Fn(model, path, inputPaths, fns) {
  this.model = model;
  this.setterModel = model.pass('fn');
  this.path = path;
  this.inputPaths = inputPaths;
  this.getFn = fns.get || fns;
  this.setFn = fns.set;
  this.pathSegments = null;
  this.inputPathsSegments = null;
}

Fn.prototype.splitPaths = function() {
  this.pathSegments = this.path.split('.');
  this.inputPathsSegments = [];
  for (var i = this.inputPaths.length; i--;) {
    var segments = this.inputPaths[i].split('.');
    this.inputPathsSegments.push(segments);
  }
};

Fn.prototype.apply = function(fn, inputs) {
  for (var i = 0, len = this.inputPaths.length; i < len; i++) {
    var input = this.model.get(this.inputPaths[i]);
    inputs.push(input);
  }
  return fn.apply(null, inputs);
};

Fn.prototype.get = function() {
  return this.apply(this.getFn, []);
};

Fn.prototype.set = function(value) {
  if (!this.setFn) return;
  var out = this.apply(this.setFn, [value]);
  if (!out) return;
  for (var index in out) {
    var path = this.inputPaths[index];
    var value = out[index];
    this.setterModel.setDiff(path, value);
  }
};

Fn.prototype.onInput = function() {
  var value = this.get();
  this.setterModel.setDiff(this.path, value);
  return value;
};

Fn.prototype.onOutput = function() {
  var value = this.model.get(this.path);
  return this.set(value);
};
