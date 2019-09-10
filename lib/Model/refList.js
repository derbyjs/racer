var Model = require('./Model');
var EventMapTree = require('./EventMapTree');
var EventListenerTree = require('./EventListenerTree');

Model.INITS.push(function(model) {
  var root = model.root;
  root._refLists = new RefLists();
  addListener(root, 'changeImmediate');
  addListener(root, 'loadImmediate');
  addListener(root, 'unloadImmediate');
  addListener(root, 'insertImmediate');
  addListener(root, 'removeImmediate');
  addListener(root, 'moveImmediate');
});

function addListener(model, type) {
  model.on(type, refListListener);
  function refListListener(segments, event) {
    var passed = event.passed;
    // Check for updates on or underneath paths
    var refLists = model._refLists.fromMap.getAffectedListeners(segments);
    for (var i = 0; i < refLists.length; i++) {
      var refList = refLists[i];
      if (passed.$refList !== refList) {
        patchFromEvent(segments, event, refList);
      }
    };
    var refLists = model._refLists.toListeners.getAffectedListeners(segments);
    for (var i = 0; i < refLists.length; i++) {
      var refList = refLists[i];
      if (passed.$refList !== refList) {
        patchToEvent(segments, event, refList);
      }
    };
    var refLists = model._refLists.idsListeners.getAffectedListeners(segments);
    for (var i = 0; i < refLists.length; i++) {
      var refList = refLists[i];
      if (passed.$refList !== refList) {
        patchIdsEvent(segments, event, refList);
      }
    }
  }
}

/**
 * @param {String} type
 * @param {Array} segments
 * @param {Event} event
 * @param {RefList} refList
 */
function patchFromEvent(segments, event, refList) {
  var type = event.type;
  var fromLength = refList.fromSegments.length;
  var segmentsLength = segments.length;
  var model = refList.model.pass(event.passed, true);

  // Mutation on the `from` output itself
  if (segmentsLength === fromLength) {
    if (type === 'insert') {
      var ids = setNewToValues(model, refList, event.values);
      model._insert(refList.idsSegments, event.index, ids);
      return;
    }

    if (type === 'remove') {
      var howMany = event.values.length;
      var ids = model._remove(refList.idsSegments, event.index, howMany);
      // Delete the appropriate items underneath `to` if the `deleteRemoved`
      // option was set true
      if (refList.deleteRemoved) {
        for (var i = 0; i < ids.length; i++) {
          var item = refList.itemById(ids[i]);
          model._del(refList.toSegmentsByItem(item));
        }
      }
      return;
    }

    if (type === 'move') {
      model._move(refList.idsSegments, event.from, event.to, event.howMany);
      return;
    }

    // Change of the entire output
    var values = (type === 'change') ?
      event.value : model._get(refList.fromSegments);
    // Set ids to empty list if output is set to null
    if (!values) {
      model._set(refList.idsSegments, []);
      return;
    }
    // If the entire output is set, create a list of ids based on the output,
    // and update the corresponding items
    var ids = setNewToValues(model, refList, values);
    model._set(refList.idsSegments, ids);
    return;
  }

  // If mutation is on a parent of `from`, we might need to re-create the
  // entire refList output
  if (segmentsLength < fromLength) {
    model._setArrayDiff(refList.fromSegments, refList.get());
    return;
  }

  var index = segments[fromLength];
  var value = model._get(refList.fromSegments.concat(index));
  var toSegments = refList.toSegmentsByItem(value);

  // Mutation underneath a child of the `from` object.
  if (segmentsLength > fromLength + 1) {
    throw new Error('Mutation on descendant of refList `from`' +
      ' should have been dereferenced: ' + segments.join('.'));
  }

  // Otherwise, mutation of a child of the `from` object

  // If changing the item itself, it will also have to be re-set on the
  // original object
  if (type === 'change') {
    model._set(toSegments, value);
    updateIdForValue(model, refList, index, value);
    return;
  }
  if (type === 'insert' || type === 'remove' || type === 'move') {
    throw new Error('Array mutation on child of refList `from`' +
      'should have been dereferenced: ' + segments.join('.'));
  }
}

/**
 * @private
 * @param {Model} model
 * @param {RefList} refList
 * @param {Array} values
 */
function setNewToValues(model, refList, values) {
  var ids = [];
  for (var i = 0; i < values.length; i++) {
    var value = values[i];
    var id = refList.idByItem(value);
    if (id === undefined && typeof value === 'object') {
      id = value.id = model.id();
    }
    var toSegments = refList.toSegmentsByItem(value);
    if (id === undefined || toSegments === undefined) {
      throw new Error('Unable to add item to refList: ' + value);
    }
    if (model._get(toSegments) !== value) {
      model._set(toSegments, value);
    }
    ids.push(id);
  }
  return ids;
}
function updateIdForValue(model, refList, index, value) {
  var id = refList.idByItem(value);
  var outSegments = refList.idsSegments.concat(index);
  model._set(outSegments, id);
}

function patchToEvent(segments, event, refList) {
  var type = event.type;
  var toLength = refList.toSegments.length;
  var segmentsLength = segments.length;
  var model = refList.model.pass(event.passed, true);

  // Mutation on the `to` object itself
  if (segmentsLength === toLength) {
    if (type === 'insert') {
      var values = event.values;
      for (var i = 0; i < values.length; i++) {
        var value = values[i];
        var indices = refList.indicesByItem(value);
        if (!indices) continue;
        for (var j = 0; j < indices.length; j++) {
          var outSegments = refList.fromSegments.concat(indices[j]);
          model._set(outSegments, value);
        }
      }
      return;
    }

    if (type === 'remove') {
      var removeIndex = event.index;
      var values = event.values;
      var howMany = values.length;
      for (var i = removeIndex, len = removeIndex + howMany; i < len; i++) {
        var indices = refList.indicesByItem(values[i]);
        if (!indices) continue;
        for (var j = 0, indicesLen = indices.length; j < indicesLen; j++) {
          var outSegments = refList.fromSegments.concat(indices[j]);
          model._set(outSegments, undefined);
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
  if (segmentsLength <= toLength) {
    // If the entire `to` object is updated, we need to re-create the
    // entire refList output and apply what is different
    model._setArrayDiff(refList.fromSegments, refList.get());
    return;
  }

  // Mutation underneath a child of the `to` object. The item will already
  // be up to date, since it is under an object reference. Just re-emit
  if (segmentsLength > toLength + 1) {
    var value = model._get(segments.slice(0, toLength + 1));
    var indices = refList.indicesByItem(value);
    if (!indices) return;
    var remaining = segments.slice(toLength + 1);
    var eventClone = event.clone();
    eventClone.passed = model._pass;
    for (var i = 0; i < indices.length; i++) {
      var index = indices[i];
      var dereferenced = refList.fromSegments.concat(index, remaining);
      dereferenced = model._dereference(dereferenced, null, refList);
      model._emitMutation(dereferenced, eventClone);
    }
    return;
  }

  // Otherwise, mutation of a child of the `to` object

  // If changing the item itself, it will also have to be re-set on the
  // array created by the refList
  if (type === 'change' || type === 'load' || type === 'unload') {
    var value = event.value;
    var previous = event.previous;
    var newIndices = refList.indicesByItem(value);
    var oldIndices = refList.indicesByItem(previous);
    if (!newIndices && !oldIndices) return;
    if (oldIndices && !equivalentArrays(oldIndices, newIndices)) {
      // The changed item used to refer to some indices, but no longer does
      for (var i = 0; i < oldIndices.length; i++) {
        var outSegments = refList.fromSegments.concat(oldIndices[i]);
        model._set(outSegments, undefined);
      }
    }
    if (newIndices) {
      for (var i = 0; i < newIndices.length; i++) {
        var outSegments = refList.fromSegments.concat(newIndices[i]);
        model._set(outSegments, value);
      }
    }
    return;
  }

  var value = model._get(segments.slice(0, toLength + 1));
  var indices = refList.indicesByItem(value);
  if (!indices) return;

  if (type === 'insert' || type === 'remove' || type === 'move') {
    // Array mutations will have already been updated via an object
    // reference, so only re-emit
    var eventClone = event.clone();
    eventClone.passed = model._pass;
    for (var i = 0; i < indices.length; i++) {
      var dereferenced = refList.fromSegments.concat(indices[i]);
      dereferenced = model._dereference(dereferenced, null, refList);
      model._emitMutation(dereferenced, eventClone);
    }
  }
}
function equivalentArrays(a, b) {
  if (!a || !b) return false;
  if (a.length !== b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

function patchIdsEvent(segments, event, refList) {
  var type = event.type;
  var idsLength = refList.idsSegments.length;
  var segmentsLength = segments.length;
  var model = refList.model.pass(event.passed, true);

  // An array mutation of the ids should be mirrored with a like change in
  // the output array
  if (segmentsLength === idsLength) {
    if (type === 'insert') {
      var inserted = event.values;
      var values = [];
      for (var i = 0; i < inserted.length; i++) {
        var value = refList.itemById(inserted[i]);
        values.push(value);
      }
      model._insert(refList.fromSegments, event.index, values);
      return;
    }

    if (type === 'remove') {
      var howMany = event.values.length;
      model._remove(refList.fromSegments, event.index, howMany);
      return;
    }

    if (type === 'move') {
      model._move(refList.fromSegments, event.from, event.to, event.howMany);
      return;
    }
  }

  // Mutation on the `ids` list itself
  if (segmentsLength <= idsLength) {
    // If the entire `ids` array is updated, we need to re-create the
    // entire refList output and apply what is different
    model._setArrayDiff(refList.fromSegments, refList.get());
    return;
  }

  // Otherwise, direct mutation of a child in the `ids` object or mutation
  // underneath an item in the `ids` list. Update the item for the appropriate
  // id if it has changed
  var index = segments[idsLength];
  var id = refList.idByIndex(index);
  var item = refList.itemById(id);
  var itemSegments = refList.fromSegments.concat(index);
  if (model._get(itemSegments) !== item) {
    model._set(itemSegments, item);
  }
}

Model.prototype.refList = function() {
  var from, to, ids, options;
  if (arguments.length === 2) {
    to = arguments[0];
    ids = arguments[1];
  } else if (arguments.length === 3) {
    if (this.isPath(arguments[2])) {
      from = arguments[0];
      to = arguments[1];
      ids = arguments[2];
    } else {
      to = arguments[0];
      ids = arguments[1];
      options = arguments[2];
    }
  } else {
    from = arguments[0];
    to = arguments[1];
    ids = arguments[2];
    options = arguments[3];
  }
  var fromPath = this.path(from);
  var toPath;
  if (Array.isArray(to)) {
    toPath = [];
    for (var i = 0; i < to.length; i++) {
      toPath.push(this.path(to[i]));
    }
  } else {
    toPath = this.path(to);
  }
  var idsPath = this.path(ids);
  var refList = new RefList(this.root, fromPath, toPath, idsPath, options);
  this.root._refLists.remove(refList.fromSegments);
  refList.model._setArrayDiff(refList.fromSegments, refList.get());
  this.root._refLists.add(refList);
  return this.scope(fromPath);
};

function RefList(model, from, to, ids, options) {
  this.model = model && model.pass({$refList: this});
  this.from = from;
  this.to = to;
  this.ids = ids;
  this.fromSegments = from && from.split('.');
  this.toSegments = to && to.split('.');
  this.idsSegments = ids && ids.split('.');
  this.options = options;
  this.deleteRemoved = options && options.deleteRemoved;
}

// The default implementation assumes that the ids array is a flat list of
// keys on the to object. Ideally, this mapping could be customized via
// inheriting from RefList and overriding these methods without having to
// modify the above event handling code.
//
// In the default refList implementation, `key` and `id` are equal.
//
// Terms in the below methods:
//   `item`  - Object on the `to` path, which gets mirrored on the `from` path
//   `key`   - The property under `to` at which an item is located
//   `id`    - String or object in the array at the `ids` path
//   `index` - The index of an id, which corresponds to an index on `from`
RefList.prototype.get = function() {
  var ids = this.model._get(this.idsSegments);
  if (!ids) return [];
  var items = this.model._get(this.toSegments);
  var out = [];
  for (var i = 0; i < ids.length; i++) {
    var key = ids[i];
    out.push(items && items[key]);
  }
  return out;
};
RefList.prototype.dereference = function(segments, i) {
  var remaining = segments.slice(i + 1);
  var key = this.idByIndex(remaining[0]);
  if (key == null) return [];
  remaining[0] = key;
  return this.toSegments.concat(remaining);
};
RefList.prototype.toSegmentsByItem = function(item) {
  var key = this.idByItem(item);
  if (key === undefined) return;
  return this.toSegments.concat(key);
};
RefList.prototype.idByItem = function(item) {
  if (item && item.id) return item.id;
  var items = this.model._get(this.toSegments);
  for (var key in items) {
    if (item === items[key]) return key;
  }
};
RefList.prototype.indicesByItem = function(item) {
  var id = this.idByItem(item);
  var ids = this.model._get(this.idsSegments);
  if (!ids) return;
  var indices;
  var index = -1;
  for (;;) {
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
RefList.prototype.itemById = function(id) {
  return this.model._get(this.toSegments.concat(id));
};
RefList.prototype.idByIndex = function(index) {
  return this.model._get(this.idsSegments.concat(index));
};

function RefLists() {
  this.fromMap = new EventMapTree();
  var toListeners = this.toListeners = new EventListenerTree();
  var idsListeners = this.idsListeners = new EventListenerTree();
  this._removeInputListeners = function(refList) {
    toListeners.removeListener(refList.toSegments, refList);
    idsListeners.removeListener(refList.idsSegments, refList);
  };
}

RefLists.prototype.add = function(refList) {
  this.fromMap.setListener(refList.fromSegments, refList);
  this.toListeners.addListener(refList.toSegments, refList);
  this.idsListeners.addListener(refList.idsSegments, refList);
};

RefLists.prototype.remove = function(fromSegments) {
  var refList = this.fromMap.deleteListener(fromSegments);
  if (!refList) return;
  this.toListeners.removeListener(refList.toSegments, refList);
  this.idsListeners.removeListener(refList.idsSegments, refList);
};

RefLists.prototype.removeAll = function(segments) {
  var node = this.fromMap.deleteAllListeners(segments);
  if (node) {
    node.forEach(this._removeInputListeners);
  }
};

RefLists.prototype.toJSON = function() {
  var out = [];
  this.fromMap.forEach(function(refList) {
    out.push([refList.from, refList.to, refList.ids, refList.options]);
  });
  return out;
};
