var util = require('../util');
var Model = require('./Model');

Model.INITS.push(function(model) {
  var root = model.root;
  root._refs = new Refs();
  addIndexListeners(root);
  addListener(root, 'change', refChange);
  addListener(root, 'load', refLoad);
  addListener(root, 'unload', refUnload);
  addListener(root, 'insert', refInsert);
  addListener(root, 'remove', refRemove);
  addListener(root, 'move', refMove);
});

function addIndexListeners(model) {
  model.on('insertImmediate', function refInsertIndex(segments, eventArgs) {
    var index = eventArgs[0];
    var howMany = eventArgs[1].length;
    function patchInsert(refIndex) {
      return (index <= refIndex) ? refIndex + howMany : refIndex;
    }
    onIndexChange(segments, patchInsert);
  });
  model.on('removeImmediate', function refRemoveIndex(segments, eventArgs) {
    var index = eventArgs[0];
    var howMany = eventArgs[1].length;
    function patchRemove(refIndex) {
      return (index <= refIndex) ? refIndex - howMany : refIndex;
    }
    onIndexChange(segments, patchRemove);
  });
  model.on('moveImmediate', function refMoveIndex(segments, eventArgs) {
    var from = eventArgs[0];
    var to = eventArgs[1];
    var howMany = eventArgs[2];
    function patchMove(refIndex) {
      // If the index was moved itself
      if (from <= refIndex && refIndex < from + howMany) {
        return refIndex + to - from;
      }
      // Remove part of a move
      if (from <= refIndex) refIndex -= howMany;
      // Insert part of a move
      if (to <= refIndex) refIndex += howMany;
      return refIndex;
    }
    onIndexChange(segments, patchMove);
  });
  function onIndexChange(segments, patch) {
    var toPathMap = model._refs.toPathMap;
    var refs = toPathMap.get(segments) || [];

    for(var i = 0, len = refs.length; i < len; i++) {
      var ref = refs[i];
      var from = ref.from;
      if (!(ref.updateIndices &&
        ref.toSegments.length > segments.length)) continue;
      var index = +ref.toSegments[segments.length];
      var patched = patch(index);
      if (index === patched) continue;
      model._refs.remove(from);
      ref.toSegments[segments.length] = '' + patched;
      ref.to = ref.toSegments.join('.');
      model._refs.add(ref);
    }
  }
}

function refChange(model, dereferenced, eventArgs, segments) {
  var value = eventArgs[0];
  // Detect if we are deleting vs. setting to undefined
  if (value === undefined) {
    var parentSegments = segments.slice();
    var last = parentSegments.pop();
    var parent = model._get(parentSegments);
    if (!parent || !(last in parent)) {
      model._del(dereferenced);
      return;
    }
  }
  model._set(dereferenced, value);
}
function refLoad(model, dereferenced, eventArgs) {
  var value = eventArgs[0];
  model._set(dereferenced, value);
}
function refUnload(model, dereferenced) {
  model._del(dereferenced);
}
function refInsert(model, dereferenced, eventArgs) {
  var index = eventArgs[0];
  var values = eventArgs[1];
  model._insert(dereferenced, index, values);
}
function refRemove(model, dereferenced, eventArgs) {
  var index = eventArgs[0];
  var howMany = eventArgs[1].length;
  model._remove(dereferenced, index, howMany);
}
function refMove(model, dereferenced, eventArgs) {
  var from = eventArgs[0];
  var to = eventArgs[1];
  var howMany = eventArgs[2];
  model._move(dereferenced, from, to, howMany);
}

function addListener(model, type, fn) {
  model.on(type + 'Immediate', refListener);
  function refListener(segments, eventArgs) {
    var pass = eventArgs[eventArgs.length - 1];
    // Find cases where an event is emitted on a path where a reference
    // is pointing. All original mutations happen on the fully dereferenced
    // location, so this detection only needs to happen in one direction
    var toPathMap = model._refs.toPathMap;
    var subpath;
    for (var i = 0, len = segments.length; i < len; i++) {
      subpath = (subpath) ? subpath + '.' + segments[i] : segments[i];
      // If a ref is found pointing to a matching subpath, re-emit on the
      // place where the reference is coming from as if the mutation also
      // occured at that path
      var refs = toPathMap.get(subpath.split('.'), true);
      if (!refs.length) continue;
      var remaining = segments.slice(i + 1);
      for (var refIndex = 0, numRefs = refs.length; refIndex < numRefs; refIndex++) {
        var ref = refs[refIndex];
        var dereferenced = ref.fromSegments.concat(remaining);
        // The value may already be up to date via object reference. If so,
        // simply re-emit the event. Otherwise, perform the same mutation on
        // the ref's path
        if (model._get(dereferenced) === model._get(segments)) {
          model.emit(type, dereferenced, eventArgs);
        } else {
          var setterModel = ref.model.pass(pass, true);
          setterModel._dereference = noopDereference;
          fn(setterModel, dereferenced, eventArgs, segments);
        }
      }
    }
    // If a ref points to a child of a matching subpath, get the value in
    // case it has changed and set if different
    var parentToPathMap = model._refs.parentToPathMap;
    var refs = parentToPathMap.get(subpath.split('.'), true);
    if (!refs.length) return;
    for (var refIndex = 0, numRefs = refs.length; refIndex < numRefs; refIndex++) {
      var ref = refs[refIndex];
      var value = model._get(ref.toSegments);
      var previous = model._get(ref.fromSegments);
      if (previous !== value) {
        var setterModel = ref.model.pass(pass, true);
        setterModel._dereference = noopDereference;
        setterModel._set(ref.fromSegments, value);
      }
    }
  }
}

Model.prototype._canRefTo = function(value) {
  return this.isPath(value) || (value && typeof value.ref === 'function');
};

Model.prototype.ref = function() {
  var from, to, options;
  if (arguments.length === 1) {
    to = arguments[0];
  } else if (arguments.length === 2) {
    if (this._canRefTo(arguments[1])) {
      from = arguments[0];
      to = arguments[1];
    } else {
      to = arguments[0];
      options = arguments[1];
    }
  } else {
    from = arguments[0];
    to = arguments[1];
    options = arguments[2];
  }
  var fromPath = this.path(from);
  var toPath = this.path(to);
  // Make ref to reffable object, such as query or filter
  if (!toPath) return to.ref(fromPath);
  var ref = new Ref(this.root, fromPath, toPath, options);
  if (ref.fromSegments.length < 2) {
    throw new Error('ref must be performed under a collection ' +
      'and document id. Invalid path: ' + fromPath);
  }
  this.root._refs.remove(fromPath);
  this.root._refLists.remove(fromPath);
  var value = this.get(to);
  ref.model._set(ref.fromSegments, value);
  this.root._refs.add(ref);
  return this.scope(fromPath);
};

Model.prototype.removeRef = function(subpath) {
  var segments = this._splitPath(subpath);
  var fromPath = segments.join('.');
  this._removeRef(segments, fromPath);
};
Model.prototype._removeRef = function(segments, fromPath) {
  this.root._refs.remove(fromPath);
  this.root._refLists.remove(fromPath);
  this._del(segments);
};

Model.prototype.removeAllRefs = function(subpath) {
  var segments = this._splitPath(subpath);
  this._removeAllRefs(segments);
};
Model.prototype._removeAllRefs = function(segments) {
  this._removePathMapRefs(segments, this.root._refs.fromPathMap);
  this._removeMapRefs(segments, this.root._refLists.fromMap);
};
Model.prototype._removePathMapRefs = function(segments, map) {
  var refs = map.getList(segments);
  for(var i = 0, len = refs.length; i < len; i++) {
    var ref = refs[i];
    this._removeRef(ref.fromSegments, ref.from);
  }
};
Model.prototype._removeMapRefs = function(segments, map) {
  for (var from in map) {
    var fromSegments = map[from].fromSegments;
    if (util.contains(segments, fromSegments)) {
      this._removeRef(fromSegments, from);
    }
  }
};

Model.prototype.dereference = function(subpath) {
  var segments = this._splitPath(subpath);
  return this._dereference(segments).join('.');
};

Model.prototype._dereference = function(segments, forArrayMutator, ignore) {
  if (segments.length === 0) return segments;
  var refs = this.root._refs.fromPathMap;
  var refLists = this.root._refLists.fromMap;
  var doAgain;
  do {
    var subpath = '';
    doAgain = false;
    for (var i = 0, len = segments.length; i < len; i++) {
      subpath = (subpath) ? subpath + '.' + segments[i] : segments[i];

      var ref = refs.get(subpath.split('.'));
      if (ref) {
        var remaining = segments.slice(i + 1);
        segments = ref.toSegments.concat(remaining);
        doAgain = true;
        break;
      }

      var refList = refLists[subpath];
      if (refList && refList !== ignore) {
        var belowDescendant = i + 2 < len;
        var belowChild = i + 1 < len;
        if (!(belowDescendant || forArrayMutator && belowChild)) continue;
        segments = refList.dereference(segments, i);
        doAgain = true;
        break;
      }
    }
  } while (doAgain);
  // If a dereference fails, return a path that will result in a null value
  // instead of a path to everything in the model
  if (segments.length === 0) return ['$null'];
  return segments;
};

function noopDereference(segments) {
  return segments;
}

function Ref(model, from, to, options) {
  this.model = model && model.pass({$ref: this});
  this.from = from;
  this.to = to;
  this.fromSegments = from.split('.');
  this.toSegments = to.split('.');
  this.parentTos = [];
  for (var i = 1, len = this.toSegments.length; i < len; i++) {
    var parentTo = this.toSegments.slice(0, i).join('.');
    this.parentTos.push(parentTo);
  }
  this.updateIndices = options && options.updateIndices;
}

function Refs() {
  this.parentToPathMap = new PathListMap();
  this.toPathMap = new PathListMap();
  this.fromPathMap = new PathMap();
}

Refs.prototype.add = function(ref) {
  this.fromPathMap.add(ref.fromSegments, ref);
  this.toPathMap.add(ref.toSegments, ref);
  for (var i = 0, len = ref.parentTos.length; i < len; i++) {
    this.parentToPathMap.add(ref.parentTos[i].split('.'), ref);
  }
};

Refs.prototype.remove = function(from) {
  var ref = this.fromPathMap.get((from || '').split('.'));
  if (!ref) return;
  this.fromPathMap.delete(ref.fromSegments);
  this.toPathMap.delete(ref.toSegments, ref);
  for (var i = 0, len = ref.parentTos.length; i < len; i++) {
    this.parentToPathMap.delete(ref.parentTos[i].split('.'), ref);
  }
  return ref;
};

Refs.prototype.toJSON = function() {
  var out = [];
  var refs = this.fromPathMap.getList([]);

  for(var i = 0, len = refs.length; i < len; i++) {
    var ref = refs[i];
    out.push([ref.from, ref.to]);
  }
  return out;
};

function PathMap() {
  this.map = {};
}

PathMap.prototype.add = function (segments, item) {
  var map = this.map;

  for(var i = 0, len = segments.length - 1; i < len; i++) {
    map[segments[i]] = map[segments[i]] || {};
    map = map[segments[i]];
  }

  map[segments[segments.length - 1]] = {"$item": item};
};

PathMap.prototype.get = function (segments) {
  var val = this._get(segments);

  return (val && val['$item']) ? val['$item'] : void 0;
};

PathMap.prototype._get = function (segments) {
  var val = this.map;

  for(var i = 0, len = segments.length; i < len; i++) {
    val = val[segments[i]];
    if(!val) return;
  }

  return val;
};

PathMap.prototype.getList = function (segments) {
  var obj = this._get(segments);

  return flattenObj(obj);
};

function flattenObj(obj) {
  if(!obj) return [];

  var arr = [];
  var keys = Object.keys(obj);
  if(obj['$item']) arr.push(obj['$item']);

  for(var i = 0, len = keys.length; i < len; i++) {
    if(keys[i] === '$item') continue;

    arr = arr.concat(flattenObj(obj[keys[i]]));
  }

  return arr;
};

PathMap.prototype.delete = function (segments) {
  del(this.map, segments.slice(0), true);
};

function del(map, segments, safe) {
  var segment = segments.shift();

  if(!segments.length) {
    if(safe) {
      delete map[segment];
      return false;
    } else {
      return true;
    }
  }

  var nextMap = map[segment];
  if(!nextMap) return true;

  var nextSafe = (Object.keys(nextMap).length > 1);
  var remove = del(nextMap, segments, nextSafe);

  if(remove) {
    if(safe) {
      delete map[segment];
      return false;
    } else {
      return true;
    }
  }
}

function PathListMap() {
  this.map = {};
}

PathListMap.prototype.add = function (segments, item) {
  var map = this.map;

  for(var i = 0, len = segments.length - 1; i < len; i++) {
    map[segments[i]] = map[segments[i]] || {"$items": []};
    map = map[segments[i]];
  }

  var segment = segments[segments.length - 1];

  map[segment] = map[segment] || {"$items": []};
  map[segment]['$items'].push(item);
};

PathListMap.prototype.get = function (segments, onlyAtLevel) {
  var val = this.map;

  for(var i = 0, len = segments.length; i < len; i++) {
    val = val[segments[i]];
    if(!val) return [];
  }

  if(onlyAtLevel) return (val['$items'] || []);

  return flatten(val);
};

function flatten(obj) {
  var arr = obj['$items'] || [];
  var keys = Object.keys(obj);

  for(var i = 0, len = keys.length; i < len; i++) {
    if(keys[i] === '$items') continue;

    arr.concat(flatten(obj[i]));
  }

  return arr;
}

PathListMap.prototype.delete = function (segments, item) {
  delList(this.map, segments.slice(0), item, true);
};

function delList(map, segments, item, safe) {
  var segment = segments.shift();

  if(!segments.length) {
    if(!map[segment] || !map[segment]['$items']) return true;

    var items = map[segment]['$items'];
    var keys = Object.keys(map[segment]);

    if(items.length < 2 && keys.length < 2) {
      if(safe) {
        delete map[segment];
        return false;
      } else {
        return true;
      }
    } else {
      var i = items.indexOf(item);

      if(i > -1) items.splice(i, 1);

      return false;
    }
  }

  var nextMap = map[segment];
  if(!nextMap) return true;

  var nextSafe = (Object.keys(nextMap).length > 2 || nextMap['$items'].length);
  var remove = delList(nextMap, segments, item, nextSafe);

  if(remove) {
    if(safe) {
      delete map[segment];
      return false;
    } else {
      return true;
    }
  }
}
