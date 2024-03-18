var util = require('../util');
import { Callback, Path, ReadonlyDeep } from '../types';
import { Model } from './Model';
import { type Segments } from './types';
var arrayDiff = require('arraydiff');
var mutationEvents = require('./events').mutationEvents;
var ChangeEvent = mutationEvents.ChangeEvent;
var InsertEvent = mutationEvents.InsertEvent;
var RemoveEvent = mutationEvents.RemoveEvent;
var MoveEvent = mutationEvents.MoveEvent;
var promisify = util.promisify;

declare module './Model' {
  interface Model<T> {
    /**
     * Sets the value at this model's path or a relative subpath, if different
     * from the current value based on a strict equality comparison (`===`).
     *
     * If a callback is provided, it's called when the write is committed or
     * fails.
     *
     * @param subpath
     * @param value
     * @returns the value previously at the path
     */
    setDiff<S>(subpath: Path, value: S, cb?: Callback): ReadonlyDeep<S> | undefined;
    setDiff(value: T): ReadonlyDeep<T> | undefined;
    setDiffPromised<S>(subpath: string, value: S): Promise<S>;
    _setDiff(segments: Segments, value: any, cb?: (err: Error) => void): void;

    /**
     * Sets the value at this model's path or a relative subpath, if different
     * from the current value based on a recursive deep equal comparison.
     *
     * This attempts to issue fine-grained ops on subpaths if possible.
     *
     * If a callback is provided, it's called when the write is committed or
     * fails.
     *
     * @param subpath
     * @param value
     * @returns the value previously at the path
     */
    setDiffDeep<S>(subpath: Path, value: S, cb?: Callback): ReadonlyDeep<S> | undefined;
    setDiffDeep(value: T): ReadonlyDeep<T> | undefined;
    setDiffDeepPromised<S>(subpath: Path, value: S): Promise<void>;
    _setDiffDeep<S>(segments: Segments, value: any, cb?: (err: Error) => void): void;

    /**
     * Sets the array value at this model's path or a relative subpath, based on
     * a strict equality comparison (`===`) between array items.
     *
     * This only issues array insert, remove, and move operations.
     *
     * If a callback is provided, it's called when the write is committed or
     * fails.
     *
     * @param subpath
     * @param value
     * @returns the value previously at the path
     */
    setArrayDiff<S extends any[]>(subpath: Path, value: S, cb?: Callback): S;
    setArrayDiff<S extends T & any[]>(value: S): S;
    setArrayDiffPromised<S extends any[]>(subpath: Path, value: S): Promise<void>;
    _setArrayDiff<S extends any[]>(segments: Segments, value: any, cb?: (err: Error) => void, equalFn?: any): void;

    /**
     * Sets the array value at this model's path or a relative subpath, based on
     * a deep equality comparison between array items.
     *
     * This only issues array insert, remove, and move operations. Unlike
     * `setDiffDeep`, this will never issue fine-grained ops inside of array
     * items.
     *
     * If a callback is provided, it's called when the write is committed or
     * fails.
     *
     * @param subpath
     * @param value
     * @returns the value previously at the path
     */
    setArrayDiffDeep<S extends any[]>(subpath: Path, value: S, cb?: Callback): S;
    setArrayDiffDeep<S extends T & any[]>(value: S): S;
    setArrayDiffDeepPromised<S extends any[]>(subpath: Path, value: S): Promise<void>;
    _setArrayDiffDeep<S extends T & any[]>(segments: Segments, value: any, cb?: (err: Error) => void): void;

    _setArrayDiff<S extends T & any[]>(segments: Segments, value: any, cb?: (err: Error) => void, equalFn?: any): S;
    _applyArrayDiff<S extends T & any[]>(segments: Segments, diff: any, cb?: (err: Error) => void): S;
  }
}

Model.prototype.setDiff = function() {
  var subpath, value, cb;
  if (arguments.length === 1) {
    value = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    value = arguments[1];
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._setDiff(segments, value, cb);
};
Model.prototype.setDiffPromised = promisify(Model.prototype.setDiff);

Model.prototype._setDiff = function(segments, value, cb) {
  segments = this._dereference(segments);
  var model = this;
  function setDiff(doc, docSegments, fnCb) {
    var previous = doc.get(docSegments);
    if (util.equal(previous, value)) {
      fnCb();
      return previous;
    }
    doc.set(docSegments, value, fnCb);
    var event = new ChangeEvent(value, previous, model._pass);
    model._emitMutation(segments, event);
    return previous;
  }
  return this._mutate(segments, setDiff, cb);
};

Model.prototype.setDiffDeep = function() {
  var subpath, value, cb;
  if (arguments.length === 1) {
    value = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    value = arguments[1];
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._setDiffDeep(segments, value, cb);
};
Model.prototype.setDiffDeepPromised = promisify(Model.prototype.setDiffDeep);

Model.prototype._setDiffDeep = function(segments, value, cb) {
  var before = this._get(segments);
  cb = this.wrapCallback(cb);
  var group = util.asyncGroup(cb);
  var finished = group();
  diffDeep(this, segments, before, value, group);
  finished();
};

function diffDeep(model, segments, before, after, group) {
  if (typeof before !== 'object' || !before ||
      typeof after !== 'object' || !after) {
    // Diff the entire value if not diffable objects
    model._setDiff(segments, after, group());
    return;
  }
  if (Array.isArray(before) && Array.isArray(after)) {
    var diff = arrayDiff(before, after, util.deepEqual);
    if (!diff.length) return;
    // If the only change is a single item replacement, diff the item instead
    if (
      diff.length === 2 &&
      diff[0].index === diff[1].index &&
      diff[0] instanceof arrayDiff.RemoveDiff &&
      diff[0].howMany === 1 &&
      diff[1] instanceof arrayDiff.InsertDiff &&
      diff[1].values.length === 1
    ) {
      var index = diff[0].index;
      var itemSegments = segments.concat(index);
      diffDeep(model, itemSegments, before[index], after[index], group);
      return;
    }
    model._applyArrayDiff(segments, diff, group());
    return;
  }

  // Delete keys that were in before but not after
  for (var key in before) {
    if (key in after) continue;
    var itemSegments = segments.concat(key);
    model._del(itemSegments, group());
  }

  // Diff each property in after
  for (var key in after) {
    if (util.deepEqual(before[key], after[key])) continue;
    var itemSegments = segments.concat(key);
    diffDeep(model, itemSegments, before[key], after[key], group);
  }
}

Model.prototype.setArrayDiff = function() {
  var subpath, value, cb;
  if (arguments.length === 1) {
    value = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    value = arguments[1];
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._setArrayDiff(segments, value, cb);
};
Model.prototype.setArrayDiffPromised = promisify(Model.prototype.setArrayDiff);

Model.prototype.setArrayDiffDeep = function() {
  var subpath, value, cb;
  if (arguments.length === 1) {
    value = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    value = arguments[1];
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._setArrayDiffDeep(segments, value, cb);
};
Model.prototype.setArrayDiffDeepPromised = promisify(Model.prototype.setArrayDiffDeep);

Model.prototype._setArrayDiffDeep = function(segments, value, cb) {
  return this._setArrayDiff(segments, value, cb, util.deepEqual);
};

Model.prototype._setArrayDiff = function(segments, value, cb, _equalFn) {
  var before = this._get(segments);
  if (before === value) return this.wrapCallback(cb)();
  if (!Array.isArray(before) || !Array.isArray(value)) {
    this._set(segments, value, cb);
    return;
  }
  var diff = arrayDiff(before, value, _equalFn);
  this._applyArrayDiff(segments, diff, cb);
};

Model.prototype._applyArrayDiff = function(segments, diff, cb) {
  if (!diff.length) return this.wrapCallback(cb)();
  segments = this._dereference(segments);
  var model = this;
  function applyArrayDiff(doc, docSegments, fnCb) {
    var group = util.asyncGroup(fnCb);
    for (var i = 0, len = diff.length; i < len; i++) {
      var item = diff[i];
      if (item instanceof arrayDiff.InsertDiff) {
        // Insert
        doc.insert(docSegments, item.index, item.values, group());
        var event = new InsertEvent(item.index, item.values, model._pass);
        model._emitMutation(segments, event);
      } else if (item instanceof arrayDiff.RemoveDiff) {
        // Remove
        var removed = doc.remove(docSegments, item.index, item.howMany, group());
        var event = new RemoveEvent(item.index, removed, model._pass);
        model._emitMutation(segments, event);
      } else if (item instanceof arrayDiff.MoveDiff) {
        // Move
        var moved = doc.move(docSegments, item.from, item.to, item.howMany, group());
        var event = new MoveEvent(item.from, item.to, moved.length, model._pass);
        model._emitMutation(segments, event);
      }
    }
  }
  return this._mutate(segments, applyArrayDiff, cb);
};
