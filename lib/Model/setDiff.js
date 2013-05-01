var Model = require('./index');
var util = require('../util');
var arrayDiff = require('./arrayDiff');

Model.prototype.setDiff = function(subpath, value, options, cb) {
  var equalFn = (options && options.equal) || util.equal;
  var isEach = options && options.each;
  var model = this;
  function setDiff(doc, segments, docSegments, fnCb) {
    var before = doc.get(docSegments);
    if (equalFn(before, value)) return fnCb();
    var group = new util.AsyncGroup(fnCb);
    doDiff(model, doc, segments, before, value, equalFn, group, isEach);
  }
  return this._mutate(subpath, setDiff, cb);
};

function doDiff(model, doc, segments, before, after, equalFn, group, isEach) {
  if (typeof before !== 'object' || !before ||
      typeof after !== 'object' || !after) {
    // Set the entire value if not diffable
    var docSegments = segments.slice(2);
    var previous = doc.set(docSegments, after, group.add());
    model.emit('change', segments, [after, previous, true, model._pass]);
    return;
  }
  if (Array.isArray(before) && Array.isArray(after)) {
    var diff = arrayDiff(before, after, equalFn);
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
      doDiff(model, doc, itemSegments, before[index], after[index], equalFn, group);
      return;
    }
    var docSegments = segments.slice(2);
    for (var i = 0, len = diff.length; i < len; i++) {
      var item = diff[i];
      if (item instanceof arrayDiff.InsertDiff) {
        // Insert
        doc.insert(docSegments, item.index, item.values, group.add());
        model.emit('insert', segments, [item.index, item.values, true, model._pass]);
      } else if (item instanceof arrayDiff.RemoveDiff) {
        // Remove
        var removed = doc.remove(docSegments, item.index, item.howMany, group.add());
        model.emit('remove', segments, [item.index, removed, true, model._pass]);
      } else if (item instanceof arrayDiff.MoveDiff) {
        // Move
        var moved = doc.move(docSegments, item.from, item.to, item.howMany, group.add());
        model.emit('move', segments, [item.from, item.to, moved.length, true, model._pass]);
      }
    }
    return;
  }
  if (!isEach) {
    // Delete keys that were in before but not after
    for (var key in before) {
      if (key in after) continue;
      var itemSegments = segments.concat(key);
      var docSegments = segments.slice(2);
      var previous = doc.del(docSegments, group.add());
      model.emit('change', itemSegments, [void 0, previous, true, model._pass]);
    }
  }
  // Diff each property in after
  for (var key in after) {
    if (equalFn(before[key], after[key])) continue;
    var itemSegments = segments.concat(key);
    doDiff(model, doc, itemSegments, before[key], after[key], equalFn, group);
  }
}
