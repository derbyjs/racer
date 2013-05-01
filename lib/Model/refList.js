var racer = require('../racer');
var Model = require('./index');

racer.on('Model:init', function(model) {
  model._refLists = new RefLists(model);
  for (var type in Model.MUTATOR_EVENTS) {
    addListener(model, type);
  }
});

function addListener(model, type) {
  model.on(type, refListListener);
  function refListListener(segments, eventArgs) {
    var pass = eventArgs[eventArgs.length - 1];
    // Check for updates on or underneath paths
    var fromMap = model._refLists.fromMap;
    var toMap = model._refLists.toMap;
    var idsMap = model._refLists.idsMap;
    for (var i = 0, len = segments.length; i < len; i++) {
      var subpath = (subpath) ? subpath + '.' + segments[i] : segments[i];
      var fromRefList = fromMap[subpath];
      var toRefList = toMap[subpath];
      var idsRefList = idsMap[subpath];
      if (fromRefList && fromRefList !== pass) {
        patchFromEvent(fromRefList.model, type, segments, eventArgs, fromRefList, i);
      }
      if (toRefList && toRefList !== pass) {
        patchToEvent(toRefList.model, type, segments, eventArgs, toRefList, i);
      }
      if (idsRefList && idsRefList !== pass) {
        patchIdsEvent(idsRefList.model, type, segments, eventArgs, idsRefList, i);
      }
    }
  }
}

function patchFromEvent(model, type, segments, eventArgs, refList, segmentIndex) {
  var fromLength = refList.fromSegments.length;

  // Mutation on the `from` output itself
  if (segmentIndex === fromLength - 1) {
    if (type === 'insert') {
      var index = eventArgs[0];
      var values = eventArgs[0];
      var ids = setNewToValues(model, refList, values);
      model.insert(refList.ids, index, ids);
      return;
    }

    if (type === 'remove') {
      var index = eventArgs[0];
      var howMany = eventArgs[1];
      model.remove(refList.ids, index, howMany);
      return;
    }

    if (type === 'move') {
      var from = eventArgs[0];
      var to = eventArgs[1];
      var howMany = eventArgs[2];
      model.move(refList.ids, from, to, howMany);
      return;
    }

    // Change of the entire output
    var values = (type === 'change') ? eventArgs[0] : model.get(refList.from);
    // Set ids to empty list if output is set to null
    if (!values) {
      model.set(refList.ids, []);
      return;
    }
    // If the entire output is set, create a list of ids based on the output,
    // and update the corresponding items
    var ids = setNewToValues(model, refList, values);
    model.set(refList.ids, ids);
    return;
  }

  // If mutation is on a parent of `from`, we might need to re-create the
  // entire refList output
  if (segmentIndex < fromLength) {
    model.setDiff(refList.from, refList.get());
    return;
  }

  var index = segments[segmentIndex + 1];
  var value = model.get(refList.from + '.' + index);
  var key = refList.keyByItem(value);

  // Mutation underneath a child of the `from` object. The item will already
  // be up to date, since it is under an object reference. Just re-emit
  if (segmentIndex > fromLength) {
    var remaining = segments.slice(segmentIndex + 1);
    var dereferenced = refList.toSegments.concat(key, remaining);
    model.emit(type, dereferenced, eventArgs);
    // The id of the item likely didn't change, but check just in case
    updateIdForValue(model, refList, index, value);
    return;
  }

  // Otherwise, mutation of a child of the `from` object

  // If changing the item itself, it will also have to be re-set on the
  // original object
  if (type === 'change') {
    model.set(refList.to + '.' + key, value);
    updateIdForValue(model, refList, index, value);
    return;
  }
  // The same goes for string mutations, since strings are immutable
  if (type === 'stringInsert') {
    var stringIndex = eventArgs[0];
    var stringValue = eventArgs[1];
    model.stringInsert(refList.to + '.' + key, stringIndex, stringValue);
    updateIdForValue(model, refList, index, value);
    return;
  }
  if (type === 'stringRemove') {
    var stringIndex = eventArgs[0];
    var howMany = eventArgs[1];
    model.stringRemove(refList.to + '.' + key, stringIndex, howMany);
    updateIdForValue(model, refList, index, value);
    return;
  }
  // Array mutations will have already been updated via an object
  // reference, so only re-emit
  var dereferenced = refList.toSegments.concat(key);
  model.emit(type, dereferenced, eventArgs);
  updateIdForValue(model, refList, index, value);
}
function setNewToValues(model, refList, values) {
  var ids = [];
  for (var i = 0, len = values.length; i < len; i++) {
    var value = values[i];
    var id = refList.idByItem(value);
    var key = refList.keyByItem(value);
    ids.push(id);
    model.setDiff(refList.to + '.' + key, value);
  }
  return ids;
}
function updateIdForValue(model, refList, index, value) {
  var id = refList.idByItem(value);
  model.setDiff(refList.ids + '.' + index, id);
}

function patchToEvent(model, type, segments, eventArgs, refList, segmentIndex) {
  var toLength = refList.toSegments.length;
  
  // Mutation on the `to` object itself
  if (segmentIndex === toLength - 1) {
    if (type === 'insert') {
      var insertIndex = eventArgs[0];
      var values = eventArgs[0];
      for (var i = 0, len = values.length; i < len; i++) {
        var indices = refList.indicesByKey(insertIndex + i);
        if (!indices) continue;
        var value = values[i];
        for (var j = 0, indicesLen = indices.length; j < indicesLen; j++) {
          model.setDiff(refList.from + '.' + indices[j], value);
        }
      }
      return;
    }

    if (type === 'remove') {
      var removeIndex = eventArgs[0];
      var howMany = eventArgs[1];
      for (var i = removeIndex, len = removeIndex + howMany; i < len; i++) {
        var indices = refList.indicesByKey(i);
        if (!indices) continue;
        for (var j = 0, indicesLen = indices.length; j < indicesLen; j++) {
          model.del(refList.from + '.' + indices[j]);
        }
      }
      return;
    }

    if (type === 'move') {
      // Moving items in the `to` object should have no effect on the output
      return;
    }
  }

  // Mutation on or above the `to` object
  if (segmentIndex < toLength) {
    // If the entire `to` object is updated, we need to re-create the
    // entire refList output and apply what is different. This will end up
    // doing an arrayDiff
    model.setDiff(refList.from, refList.get());
    return;
  }

  var indices = refList.indicesByKey(segments[segmentIndex + 1]);
  if (!indices) return;

  // Mutation underneath a child of the `to` object. The item will already
  // be up to date, since it is under an object reference. Just re-emit
  if (segmentIndex > toLength) {
    var remaining = segments.slice(segmentIndex + 1);
    for (var i = 0, len = indices.length; i < len; i++) {
      var index = indices[i];
      var dereferenced = refList.fromSegments.concat(index, remaining);
      model.emit(type, dereferenced, eventArgs);
    }
    return;
  }

  // Otherwise, mutation of a child of the `to` object

  // If changing the item itself, it will also have to be re-set on the
  // array created by the refList
  if (type === 'change') {
    var value = eventArgs[0];
    for (var i = 0, len = indices.length; i < len; i++) {
      var index = indices[i];
      model.set(refList.from + '.' + index, value);
    }
    return;
  }
  // The same goes for string mutations, since strings are immutable
  if (type === 'stringInsert') {
    var stringIndex = eventArgs[0];
    var value = eventArgs[1];
    for (var i = 0, len = indices.length; i < len; i++) {
      var index = indices[i];
      model.stringInsert(refList.from + '.' + index, stringIndex, value);
    }
    return;
  }
  if (type === 'stringRemove') {
    var stringIndex = eventArgs[0];
    var howMany = eventArgs[1];
    for (var i = 0, len = indices.length; i < len; i++) {
      var index = indices[i];
      model.stringRemove(refList.from + '.' + index, stringIndex, howMany);
    }
    return;
  }
  // Array mutations will have already been updated via an object
  // reference, so only re-emit
  for (var i = 0, len = indices.length; i < len; i++) {
    var index = indices[i];
    var dereferenced = refList.fromSegments.concat(index);
    model.emit(type, dereferenced, eventArgs);
  }
}

function patchIdsEvent(model, type, segments, eventArgs, refList, segmentIndex) {
  var idsLength = refList.idsSegments.length;

  // Mutation on the `ids` list itself
  if (segmentIndex < idsLength) {
    // If the entire `ids` array is updated, we need to re-create the
    // entire refList output and apply what is different. This will end up
    // doing an arrayDiff
    model.setDiff(refList.from, refList.get());
    return;
  }

  // An array mutation of the ids should be mirrored with a like change in
  // the output array
  if (segmentIndex === idsLength) {
    if (type === 'insert') {
      var index = eventArgs[0];
      var inserted = eventArgs[1];
      var values = [];
      for (var i = 0, len = inserted.length; i < len; i++) {
        var value = refList.itemByIndex(inserted[i]);
        values.push(value);
      }
      model.insert(refList.from, index, values);
      return;
    }

    if (type === 'remove') {
      var index = eventArgs[0];
      var howMany = eventArgs[1];
      model.remove(refList.from, index, howMany);
      return;
    }

    if (type === 'move') {
      var from = eventArgs[0];
      var to = eventArgs[1];
      var howMany = eventArgs[2];
      model.move(refList.from, from, to, howMany);
      return;
    }
  }

  // Otherwise, direct mutation of a child in the `ids` object or mutation
  // underneath an item in the `ids` list. Update the item for the appropriate
  // id if it has changed
  var index = segments[segmentIndex + 1];
  var item = refList.itemByIndex(index);
  model.setDiff(refList.from + '.' + index, item);
}

Model.prototype.refList = function(from, to, ids) {
  var fromPath = this.path(from);
  var toPath = this.path(to);
  var idsPath = this.path(ids);
  var refList = this._refLists.add(fromPath, toPath, idsPath);
  refList.model.set(fromPath, refList.get());
};

Model.prototype.removeRefList = function(from) {
  var fromPath = this.path(from);
  this._refLists.remove(fromPath);
};

function RefList(model, from, to, ids) {
  this.model = model.pass(this);
  this.from = from;
  this.to = to;
  this.ids = ids;
  this.fromSegments = from.split('.');
  this.toSegments = to.split('.');
  this.idsSegments = ids.split('.');
}

// The default implementation assumes that the ids array is a flat list of
// keys on the to object. Ideally, this mapping could be customized via
// inheriting from RefList and overriding these methods without having to
// modify the above event handling code.
// 
// Terms in the below methods:
//   `item`  - Object on the `to` path, which gets mirrored on the `from` path
//   `key`   - The property under `to` at which an item is located
//   `id`    - String or object in the array at the `ids` path
//   `index` - The index of an id, which corresponds to an index on `from`
RefList.prototype.get = function() {
  var out = [];
  var items = this.model.get(this.to);
  var ids = this.model.get(this.ids);
  if (!items || !ids) return out;
  for (var i = 0, len = ids.length; i < len; i++) {
    var key = ids[i];
    out.push(items[key]);
  }
  return out;
};
RefList.prototype.keyByItem = function(item) {
  return item && item.id;
};
RefList.prototype.idByItem = function(item) {
  if (!item) return;
  return item.id || (item.id = this.model.id());
};
RefList.prototype.indicesByKey = function(key) {
  var item = this.model.get(this.to + '.' + key);
  var id = this.idByItem(item);
  var ids = this.model.get(this.ids);
  if (!ids) return;
  var indices;
  var index = -1;
  while (true) {
    index = ids.indexOf(id, index + 1);
    if (index === -1) break;
    if (indices) {
      indices.push(index);
    } else {
      indices = [index];
    }
  }
  return indices;
};
RefList.prototype.itemByIndex = function(index) {
  var id = this.model.get(this.ids + '.' + index);
  return this.model.get(this.to + '.' + id);
};

function FromMap() {}
function ToMap() {}
function IdsMap() {}

function RefLists(model) {
  this.model = model;
  this.fromMap = new FromMap;
  this.toMap = new ToMap;
  this.idsMap = new IdsMap;
}

RefLists.prototype.add = function(from, to, ids) {
  var refList = new RefList(this.model, from, to, ids);
  this.fromMap[from] = refList;
  this.toMap[to] = refList;
  this.idsMap[ids] = refList;
  return refList;
};

RefLists.prototype.remove = function(from) {
  var refList = this.fromMap[from];
  if (!refList) return;
  delete this.fromMap[from];
  delete this.toMap[refList.to];
  delete this.idsMap[refList.ids];
  return refList;
};
