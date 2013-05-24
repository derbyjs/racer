var util = require('../util');
var Model = require('./index');
var defaultFns = require('./defaultFns');

Model.INITS.push(function(model) {
  model._namedFns = Object.create(defaultFns);
  model._fns = new Fns(model);
  model.on('all', fnListener);
  function fnListener(segments, eventArgs) {
    var pass = eventArgs[eventArgs.length - 1];
    var map = model._fns.fromMap;
    for (var path in map) {
      var fn = map[path];
      if (pass.$fn === fn) continue;
      if (util.mayImpactAny(fn.inputsSegments, segments)) {
        // Mutation affecting input path
        fn.onInput(pass);
      } else if (util.mayImpact(fn.fromSegments, segments)) {
        // Mutation affecting output path
        fn.onOutput(pass);
      }
    }
  }
});

Model.prototype.fn = function(name, fns) {
  this._namedFns[name] = fns;
};

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

Model.prototype.stopAll = function(subpath) {
  var segments = this._splitPath(subpath);
  var fns = this._fns.fromMap;
  for (var from in fns) {
    if (util.contains(segments, fns[from].fromSegments)) {
      this.stop(from);
    }
  }
};

function FromMap() {}
function Fns(model) {
  this.model = model;
  this.nameMap = model._namedFns;
  this.fromMap = new FromMap;
}

Fns.prototype.get = function(name, inputPaths) {
  var fns = this.nameMap[name];
  if (!fns) {
    var err = new TypeError('Model function not found: ' + name);
    this.model.emit('error', err);
  }
  var fn = new Fn(this.model, name, null, inputPaths, fns);
  return fn.get();
};

Fns.prototype.start = function(name, path, inputPaths) {
  var fns = this.nameMap[name];
  var fn = new Fn(this.model, name, path, inputPaths, fns);
  this.fromMap[path] = fn;
  return fn.onInput();
};

Fns.prototype.stop = function(path) {
  delete this.fromMap[path];
};

Fns.prototype.toJSON = function() {
  var out = [];
  for (var from in this.fromMap) {
    var fn = this.fromMap[from];
    out.push([fn.name, fn.from, fn.inputPaths]);
  }
  return out;
};

function Fn(model, name, from, inputPaths, fns) {
  this.model = model.pass({$fn: this});
  this.name = name;
  this.from = from;
  this.inputPaths = inputPaths;
  this.getFn = fns.get || fns;
  this.setFn = fns.set;
  this.fromSegments = from && from.split('.');
  this.inputsSegments = [];
  for (var i = 0; i < this.inputPaths.length; i++) {
    var segments = this.inputPaths[i].split('.');
    this.inputsSegments.push(segments);
  }
}

Fn.prototype.apply = function(fn, inputs) {
  for (var i = 0, len = this.inputsSegments.length; i < len; i++) {
    var input = this.model._get(this.inputsSegments[i]);
    inputs.push(input);
  }
  return fn.apply(this.model, inputs);
};

Fn.prototype.get = function() {
  return this.apply(this.getFn, []);
};

var diffOptions = {equal: util.deepEqual};
var eachDiffOptions = {each: true, equal: util.deepEqual};

Fn.prototype.set = function(value, pass) {
  if (!this.setFn) return;
  var out = this.apply(this.setFn, [value]);
  if (!out) return;
  var inputsSegments = this.inputsSegments;
  var model = this.model.pass(pass);
  for (var key in out) {
    if (key === 'each') {
      var each = out[key];
      for (key in each) {
        var value = util.deepCopy(each[key]);
        model._setDiff(inputsSegments[key], value, eachDiffOptions);
      }
      continue;
    }
    var value = util.deepCopy(out[key]);
    model._setDiff(inputsSegments[key], value, diffOptions);
  }
};

Fn.prototype.onInput = function(pass) {
  var value = util.deepCopy(this.get());
  this.model.pass(pass)._setDiff(this.fromSegments, value, diffOptions);
  return value;
};

Fn.prototype.onOutput = function(pass) {
  var value = this.model._get(this.fromSegments);
  return this.set(value, pass);
};
