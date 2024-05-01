import { Model } from './Model';
import { EventListenerTree } from './EventListenerTree';
import { EventMapTree } from './EventMapTree';
import * as defaultFns from './defaultFns';
import type { Path, PathLike, ReadonlyDeep, Segments } from '../types';
var util = require('../util');

class NamedFns { }

type StartFnParam = string | number | boolean | null | undefined | ReadonlyDeep<unknown>;

type ModelFn<Ins extends unknown[], Out> =
  (...inputs: Ins) => Out |
  {
    get(...inputs: Ins): Out,
    set(output: Out, ...inputs: Ins): void,
  };

interface ModelStartOptions {
  /**
   * Whether to deep-copy the input/output of the reactive function.
   *
   * - `output` (default)
   * - `input`
   * - `both`
   * - `none`
   */
  copy?: 'output' | 'input' | 'both' | 'none';
  /**
   * Comparison mode for the output of the reactive function, when determining
   * whether and how to update the output path based on the function's return
   * value.
   *
   * - `'diffDeep'` (default) - Do a recursive deep-equal comparison on old
   *   and new output values, attempting to issue fine-grained ops on subpaths
   *   where possible.
   * - `'diff` - Do an identity comparison (`===`) on the output value, and do
   *   a simple set if old and new outputs are different.
   * - `'arrayDeep'` - Compare old and new arrays item-by-item using a
   *   deep-equal comparison for each item, issuing top-level array insert,
   *   remove,, and move ops as needed. Unlike `'diffDeep'`, this will _not_
   *   issue ops inside array items.
   * - `'array'` - Compare old and new arrays item-by-item using identity
   *   comparison (`===`) for each item, issuing top-level array insert,
   *   remove,, and move ops as needed.
   */
  mode?: 'diffDeep' | 'diff' | 'arrayDeep' | 'array';
  /**
   * If true, then upon input changes, defer evaluation of the function to the
   * next tick, instead of immediately evaluating the function upon each input
   * change.
   *
   * _Warning:_ Avoid using `async: true` if there's any controller code that
   * does a `model.get()` on the output path or on any paths downstream of the
   * output, since changes to an input path won't immediately result in the
   * output being updated.
   */
  async?: boolean;
}

declare module './Model' {
  interface Model {
    /**
     * Call the function with the values at the input paths, returning the value
     * on completion. Unlike `start`, this only occurs once and does not create
     * a listener for updating based on changes.
     *
     * The function should be a pure function - it should always return the same
     * result given the same inputs, and it should be side-effect free.
     *
     * @param inputPaths
     * @param options
     * @param fn
     *
     * @see https://derbyjs.github.io/derby/models/reactive-functions
     */
    evaluate<Out, Ins extends StartFnParam[]>(
      inputPaths: PathLike[],
      options: ModelStartOptions,
      fn: (...inputs: Ins) => Out
    ): Out;
    evaluate<Out, Ins extends StartFnParam[]>(
      inputPaths: PathLike[],
      fn: (...inputs: Ins) => Out
    ): Out;

    /**
     * Defines a named reactive function.
     *
     * It's not recommended to use this in most cases. Instead, to share reactive functions,
     * have the components import a shared function to pass to `model.start`.
     *
     * @param name name of the function to define
     * @param fn either a reactive function that accepts inputs and returns output, or
     *   a `{ get: Function; set: Function }` object defining a two-way reactive function
     */
    fn<Ins extends unknown[], Out>(
      name: string,
      fn: (...inputs: Ins) => Out |
        {
          get(...inputs: Ins): Out;
          set(output: Out, ...inputs: Ins): void
        }
    ): void;

    /**
     * Call the function with the values at the input paths, writing the return
     * value to the output path. In addition, whenever any of the input values
     * change, re-invoke the function and set the new return value to the output
     * path.
     *
     * The function should be a pure function - it should always return the same
     * result given the same inputs, and it should be side-effect free.
     *
     * @param outputPath
     * @param inputPaths
     * @param options
     * @param fn - a reactive function that accepts inputs and returns output;
     *   a `{ get: Function; set: Function }` object defining a two-way reactive function;
     *   or the name of a function defined via model.fn()
     * 
     * @see https://derbyjs.github.io/derby/models/reactive-functions
     */
    start<Out, Ins extends StartFnParam[]>(
      outputPath: PathLike,
      inputPaths: PathLike[],
      options: ModelStartOptions,
      fn: ModelFn<Ins, Out> | string
    ): Out;
    start<Out, Ins extends StartFnParam[]>(
      outputPath: PathLike,
      inputPaths: PathLike[],
      fn: ModelFn<Ins, Out> | string
    ): Out;
    
    stop(subpath: Path): void;
    stopAll(subpath: Path): void;

    _fns: Fns;
    _namedFns: NamedFns;
    _stop(segments: Segments): void;
    _stopAll(segments: Segments): void;
  }
}

Model.INITS.push(function (model) {
  var root = model.root;
  root._namedFns = new NamedFns();
  root._fns = new Fns(root);
  addFnListener(root);
});

function addFnListener(model) {
  var inputListeners = model._fns.inputListeners;
  var fromMap = model._fns.fromMap;
  model.on('all', function fnListener(segments, event) {
    var passed = event.passed;
    // Mutation affecting input path
    var fns = inputListeners.getAffectedListeners(segments);
    for (var i = 0; i < fns.length; i++) {
      var fn = fns[i];
      if (fn !== passed.$fn) fn.onInput(passed);
    }
    // Mutation affecting output path
    var fns = fromMap.getAffectedListeners(segments);
    for (var i = 0; i < fns.length; i++) {
      var fn = fns[i];
      if (fn !== passed.$fn) fn.onOutput(passed);
    }
  });
}

Model.prototype.fn = function (name, fns) {
  this.root._namedFns[name] = fns;
};

function parseStartArguments(model, args, hasPath) {
  var last = args.pop();
  var fns, name;
  if (typeof last === 'string') {
    name = last;
  } else {
    fns = last;
  }
  // For `Model#start`, the first parameter is the output path.
  var path;
  if (hasPath) {
    path = model.path(args.shift());
  }
  // The second-to-last original argument could be an options object.
  // If it's not an array and not path-like, then it's an options object.
  last = args[args.length - 1];
  var options;
  if (!Array.isArray(last) && !model.isPath(last)) {
    options = args.pop();
  }

  // `args` is just the input paths at this point.
  var inputs;
  if (args.length === 1 && Array.isArray(args[0])) {
    // Inputs provided as one array:
    //   model.start(outPath, [inPath1, inPath2], fn);
    inputs = args[0];
  } else {
    // Inputs provided as var-args:
    //   model.start(outPath, inPath1, inPath2, fn);
    inputs = args;
  }

  // Normalize each input into a string path.
  var i = inputs.length;
  while (i--) {
    inputs[i] = model.path(inputs[i]);
  }
  return {
    name: name,
    path: path,
    inputPaths: inputs,
    fns: fns,
    options: options
  };
}

Model.prototype.evaluate = function () {
  var args = Array.prototype.slice.call(arguments);
  var parsed = parseStartArguments(this, args, false);
  return this.root._fns.get(parsed.name, parsed.inputPaths, parsed.fns, parsed.options);
};

Model.prototype.start = function () {
  var args = Array.prototype.slice.call(arguments);
  var parsed = parseStartArguments(this, args, true);
  return this.root._fns.start(parsed.name, parsed.path, parsed.inputPaths, parsed.fns, parsed.options);
};

Model.prototype.stop = function (subpath) {
  var segments = this._splitPath(subpath);
  this._stop(segments);
};
Model.prototype._stop = function (segments) {
  this.root._fns.stop(segments);
};

Model.prototype.stopAll = function (subpath) {
  var segments = this._splitPath(subpath);
  this._stopAll(segments);
};
Model.prototype._stopAll = function (segments) {
  this.root._fns.stopAll(segments);
};

class Fns {
  model: Model;
  nameMap: NamedFns;
  fromMap: EventMapTree;
  inputListeners: EventListenerTree;

  constructor(model: Model) {
    this.model = model;
    this.nameMap = model._namedFns;
    this.fromMap = new EventMapTree();
    this.inputListeners = new EventListenerTree();
  }

  _removeInputListeners(fn) {
    for (var i = 0; i < fn.inputsSegments.length; i++) {
      var inputSegements = fn.inputsSegments[i];
      this.inputListeners.removeListener(inputSegements, fn);
    }
  };

  get(name: string, inputPaths: any, fns: any, options: any) {
    fns || (fns = this.nameMap[name] || defaultFns[name]);
    var fn = new Fn(this.model, name, null, inputPaths, fns, options);
    return fn.get();
  };
  
  start(name: string, path: string, inputPaths: any, fns: any, options: any) {
    fns || (fns = this.nameMap[name] || defaultFns[name]);
    var fn = new Fn(this.model, name, path, inputPaths, fns, options);
    var previous = this.fromMap.setListener(fn.fromSegments, fn);
    if (previous) {
      this._removeInputListeners(previous);
    }
    for (var i = 0; i < fn.inputsSegments.length; i++) {
      var inputSegements = fn.inputsSegments[i];
      this.inputListeners.addListener(inputSegements, fn);
    }
    return fn._onInput();
  };
  
  stop(segments: Segments) {
    var previous = this.fromMap.deleteListener(segments);
    if (previous) {
      this._removeInputListeners(previous);
    }
  };
  
  stopAll(segments: Segments) {
    var node = this.fromMap.deleteAllListeners(segments);
    if (node) {
      node.forEach(node => this._removeInputListeners(node));
    }
  };
  
  toJSON() {
    var out = [];
    this.fromMap.forEach(function (fn) {
      // Don't try to bundle non-named functions that were started via
      // model.start directly instead of by name
      if (!fn.name) return;
      var args = [fn.from].concat(fn.inputPaths);
      if (fn.options) args.push(fn.options);
      args.push(fn.name);
      out.push(args);
    });
    return out;
  };
}

function Fn(model, name, from, inputPaths, fns, options) {
  this.model = model.pass({ $fn: this });
  this.name = name;
  this.from = from;
  this.inputPaths = inputPaths;
  this.options = options;
  if (!fns) {
    throw new TypeError('Model function not found: ' + name);
  }
  this.getFn = fns.get || fns;
  this.setFn = fns.set;
  this.fromSegments = from && from.split('.');
  this.inputsSegments = [];
  for (var i = 0; i < this.inputPaths.length; i++) {
    var segments = this.inputPaths[i].split('.');
    this.inputsSegments.push(segments);
  }

  // Copy can be 'output', 'input', 'both', or 'none'
  var copy = (options && options.copy) || 'output';
  this.copyInput = (copy === 'input' || copy === 'both');
  this.copyOutput = (copy === 'output' || copy === 'both');

  // Mode can be 'diffDeep', 'diff', 'arrayDeep', or 'array'
  this.mode = (options && options.mode) || 'diffDeep';

  this.async = !!(options && options.async);
  this.eventPending = false;
}

Fn.prototype.apply = function (fn, inputs) {
  for (var i = 0, len = this.inputsSegments.length; i < len; i++) {
    var input = this.model._get(this.inputsSegments[i]);
    inputs.push(this.copyInput ? util.deepCopy(input) : input);
  }
  return fn.apply(this.model, inputs);
};

Fn.prototype.get = function () {
  return this.apply(this.getFn, []);
};

Fn.prototype.set = function (value, pass) {
  if (!this.setFn) return;
  var out = this.apply(this.setFn, [value]);
  if (!out) return;
  var inputsSegments = this.inputsSegments;
  var model = this.model.pass(pass, true);
  for (var key in out) {
    var value = (this.copyOutput) ? util.deepCopy(out[key]) : out[key];
    this._setValue(model, inputsSegments[key], value);
  }
};

Fn.prototype.onInput = function (pass) {
  if (this.async) {
    if (this.eventPending) return;
    this.eventPending = true;
    var fn = this;
    process.nextTick(function () {
      fn._onInput(pass);
      fn.eventPending = false;
    });
    return;
  }
  return this._onInput(pass);
};

Fn.prototype._onInput = function (pass) {
  var value = (this.copyOutput) ? util.deepCopy(this.get()) : this.get();
  this._setValue(this.model.pass(pass, true), this.fromSegments, value);
  return value;
};

Fn.prototype.onOutput = function (pass) {
  var value = this.model._get(this.fromSegments);
  return this.set(value, pass);
};

Fn.prototype._setValue = function (model, segments, value) {
  if (this.mode === 'diffDeep') {
    model._setDiffDeep(segments, value);
  } else if (this.mode === 'arrayDeep') {
    model._setArrayDiffDeep(segments, value);
  } else if (this.mode === 'array') {
    model._setArrayDiff(segments, value);
  } else {
    model._setDiff(segments, value);
  }
};
