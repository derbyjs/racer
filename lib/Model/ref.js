var util = require('../util');
var Model = require('./index');

Model.INITS.push(function(model) {
  model._refs = new Refs;
  addArrayListeners(model);
  for (var type in Model.MUTATOR_EVENTS) {
    addListener(model, type);
  }
});

function addArrayListeners(model) {
  model.on('insert', function refInsertListener(segments, eventArgs) {
    var index = eventArgs[0];
    var howMany = eventArgs[1].length;
    function patchInsert(refIndex) {
      return (index <= refIndex) ? refIndex + howMany : refIndex;
    }
    onIndexChange(segments, patchInsert);
  });
  model.on('remove', function refRemoveListener(segments, eventArgs) {
    var index = eventArgs[0];
    var howMany = eventArgs[1].length;
    function patchRemove(refIndex) {
      return (index <= refIndex) ? refIndex - howMany : refIndex;
    }
    onIndexChange(segments, patchRemove);
  });
  model.on('move', function refMoveListener(segments, eventArgs) {
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
    var fromMap = model._refs.fromMap;
    for (var from in fromMap) {
      var ref = fromMap[from];
      if (!(ref.updateIndices &&
        util.contains(segments, ref.toSegments) &&
        ref.toSegments.length > segments.length)) continue;
      var index = +ref.toSegments[segments.length];
      var patched = patch(index);
      if (index === patched) continue;
      model._refs.remove(from);
      ref.toSegments[segments.length] = '' + patched;
      ref.to = ref.toSegments.join('.');
      model._refs._add(ref);
    }
  }
}

function addListener(model, type) {
  model.on(type, refListener);
  function refListener(segments, eventArgs) {
    var toMap = model._refs.toMap;
    // Find cases where an event is emitted on a path where a reference
    // is pointing. All original mutations happen on the fully dereferenced
    // location, so this detection only needs to happen in one direction
    for (var i = 0, len = segments.length; i < len; i++) {
      var subpath = (subpath) ? subpath + '.' + segments[i] : segments[i];
      var refs = toMap[subpath];
      if (! (refs && refs.length)) continue;
      // If a ref is found pointing to a matching subpath, re-emit on the
      // place where the reference is coming from as if the mutation also
      // occured at that path
      var remaining = segments.slice(i + 1);
      for (var refIndex = 0, numRefs = refs.length; refIndex < numRefs; refIndex++) {
        var ref = refs[refIndex];
        var dereferenced = ref.fromSegments.concat(remaining);
        model.emit(type, dereferenced, eventArgs);
      }
    }
  }
}

Model.prototype.ref = function() {
  var from, to, options;
  if (arguments.length === 1) {
    to = arguments[0];
  } else if (arguments.length === 2) {
    if (this.isPath(arguments[1])) {
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
  var fromSegments = fromPath.split('.');
  if (fromSegments.length < 2) {
    var message = 'ref must be performed under a collection ' +
      'and document id. Invalid path: ' + fromPath;
    this.emit('error', new Error(message));
  }
  var previous = this._get(fromSegments);
  this._refs.add(fromPath, toPath, options);
  var value = this._get(fromSegments);
  this.emit('change', fromSegments, [value, previous, this._pass]);
  return this.scope(fromPath);
};

Model.prototype.removeRef = function(from) {
  var fromPath = this.path(from);
  var fromSegments = fromPath.split('.');
  var previous = this._get(fromSegments);
  this._refs.remove(fromPath);
  var value = this._get(fromSegments);
  this.emit('change', fromSegments, [value, previous, this._pass]);
};

Model.prototype.removeAllRefs = function(subpath) {
  var segments = this._splitPath(subpath);
  var refs = this._refs.fromMap;
  var refLists = this._refLists.fromMap;
  for (var from in refs) {
    if (util.contains(segments, refs[from].fromSegments)) {
      this.removeRef(from);
    }
  }
  for (var from in refLists) {
    if (util.contains(segments, refLists[from].fromSegments)) {
      this.removeRefList(from);
    }
  }
};

Model.prototype.dereference = function(subpath) {
  var segments = this._splitPath(subpath);
  return this._dereference(segments).join('.');
};

Model.prototype._dereference = function(segments, forArrayMutator, ignore) {
  var refs = this._refs.fromMap;
  var refLists = this._refLists.fromMap;
  do {
    var subpath = '';
    var doAgain = false;
    for (var i = 0, len = segments.length; i < len; i++) {
      subpath = (subpath) ? subpath + '.' + segments[i] : segments[i];

      var ref = refs[subpath];
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
  return segments;
};

function Ref(from, to, options) {
  this.from = from;
  this.to = to;
  this.fromSegments = from.split('.');
  this.toSegments = to.split('.');
  this.updateIndices = options && options.updateIndices;
}
function FromMap() {}
function ToMap() {}

function Refs() {
  this.fromMap = new FromMap;
  this.toMap = new ToMap;
}

Refs.prototype.add = function(from, to, options) {
  this.remove(from);
  var ref = new Ref(from, to, options);
  return this._add(ref);
};

Refs.prototype._add = function(ref) {
  this.fromMap[ref.from] = ref;
  this.toMap[ref.to] || (this.toMap[ref.to] = []);
  this.toMap[ref.to].push(ref);
  return ref;
};

Refs.prototype.remove = function(from) {
  var ref = this.fromMap[from];
  if (!ref) return;
  delete this.fromMap[from];
  var refs = this.toMap[ref.to];
  refs.splice(refs.indexOf(ref), 1);
  if (! refs.length) {
    delete this.toMap[ref.to];
  }
  return ref;
};

Refs.prototype.toJSON = function() {
  var out = [];
  for (var from in this.fromMap) {
    var ref = this.fromMap[from];
    out.push([ref.from, ref.to]);
  }
  return out;
};
