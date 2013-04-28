var Model = require('./index');
var util = require('../util');
var arrayDiff = require('./arrayDiff');

Model.prototype.setDiff = function(subpath, value, equalFn, cb) {
  if (!equalFn) equalFn = util.equal;
  var model = this;
  function setDiff(doc, segments, fnCb) {
    var previous = doc.get(segments.slice(2));
    if (equalFn(previous, value)) return fnCb();
    var group = new util.AsyncGroup(fnCb);
    doDiff(model, doc, segments, previous, value, equalFn, group);
  }
  return this._mutate(subpath, setDiff, cb);
};

function doDiff(model, doc, segments, before, after, equalFn, group) {
  if (typeof before !== 'object' || !before ||
      typeof after !== 'object' || !after) {
    // Set the entire value if not diffable
    var previous = doc.set(segments.slice(2), after, group.add());
    model.emit('change', segments, [after, previous, true, model._pass]);
    return;
  }
  if (Array.isArray(before) && Array.isArray(after)) {
    var diff = arrayDiff(before, after, equalFn);
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
  // Delete keys that were in before but not after
  for (var key in before) {
    if (key in after) continue;
    var itemSegments = segments.concat(key);
    var previous = doc.del(itemSegments.slice(2), group.add());
    model.emit('change', itemSegments, [void 0, previous, true, model._pass]);
  }
  // Diff each property in after
  for (var key in after) {
    if (equalFn(before[key], after[key])) continue;
    var itemSegments = segments.concat(key);
    doDiff(model, doc, itemSegments, before[key], after[key], equalFn, group);
  }
}
