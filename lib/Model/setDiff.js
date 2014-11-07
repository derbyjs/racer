var util = require('../util');
var Model = require('./Model');
var arrayDiff = require('arraydiff');

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
    model.emit('change', segments, [value, previous, model._pass]);
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
    // Set the entire value if not diffable
    model._set(segments, after, group());
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
        model.emit('insert', segments, [item.index, item.values, model._pass]);
      } else if (item instanceof arrayDiff.RemoveDiff) {
        // Remove
        var removed = doc.remove(docSegments, item.index, item.howMany, group());
        model.emit('remove', segments, [item.index, removed, model._pass]);
      } else if (item instanceof arrayDiff.MoveDiff) {
        // Move
        var moved = doc.move(docSegments, item.from, item.to, item.howMany, group());
        model.emit('move', segments, [item.from, item.to, moved.length, model._pass]);
      }
    }
  }
  return this._mutate(segments, applyArrayDiff, cb);
};
