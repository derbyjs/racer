var Model = require('./index');

Model.INITS.push(function(model) {
  model._refs = new Refs;
  for (var type in Model.MUTATOR_EVENTS) {
    addListener(model, type);
  }
});

function addListener(model, type) {
  model.on(type, refListener);
  function refListener(segments, eventArgs) {
    var toMap = model._refs.toMap;
    // Find cases where an event is emitted on a path where a reference
    // is pointing. All original mutations happen on the fully dereferenced
    // location, so this detection only needs to happen in one direction
    for (var i = 0, len = segments.length; i < len; i++) {
      var subpath = (subpath) ? subpath + '.' + segments[i] : segments[i];
      var ref = toMap[subpath];
      if (!ref) continue;
      // If a ref is found pointing to a matching subpath, re-emit on the
      // place where the reference is coming from as if the mutation also
      // occured at that path
      var remaining = segments.slice(i + 1);
      var dereferenced = ref.fromSegments.concat(remaining);
      model.emit(type, dereferenced, eventArgs);
    }
  }
}

Model.prototype.ref = function() {
  var from, to;
  if (arguments.length === 1) {
    to = arguments[0];
  } else {
    from = arguments[0];
    to = arguments[1];
  }
  var fromPath = this.path(from);
  var toPath = this.path(to);
  this._refs.add(fromPath, toPath);
  return this.scope(fromPath);
};

Model.prototype.removeRef = function(from) {
  var fromPath = this.path(from);
  this._refs.remove(fromPath);
};

Model.prototype.removeAllRefs = function(subpath) {
  var segments = this._splitPath(subpath);
  var model = this;
  var refs = this._refs.fromMap;
  var refLists = this._refLists.fromMap;
  for (var from in refs) {
    if (contains(segments, refs[from].fromSegments)) {
      this.removeRef(from);
    }
  }
  for (var from in refLists) {
    if (contains(segments, refLists[from].fromSegments)) {
      this.removeRefList(from);
    }
  }
};

function contains(segments, testSegments) {
  for (var i = 0; i < segments.length; i++) {
    if (segments[i] !== testSegments[i]) return false;
  }
  return true;
}

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
        var remaining = segments.slice(i + 1);
        remaining[0] = refList.keyByIndex(remaining[0]);
        segments = refList.toSegments.concat(remaining);
        doAgain = true;
        break;
      }
    }
  } while (doAgain);
  return segments;
};

function Ref(from, to) {
  this.from = from;
  this.to = to;
  this.fromSegments = from.split('.');
  this.toSegments = to.split('.');
}
function FromMap() {}
function ToMap() {}

function Refs() {
  this.fromMap = new FromMap;
  this.toMap = new ToMap;
}

Refs.prototype.add = function(from, to) {
  this.remove(from);
  var ref = new Ref(from, to);
  this.fromMap[from] = ref;
  this.toMap[to] = ref;
};

Refs.prototype.remove = function(from) {
  var ref = this.fromMap[from];
  if (!ref) return;
  delete this.fromMap[from];
  delete this.toMap[ref.to];
};

Refs.prototype.toJSON = function() {
  var out = [];
  for (var from in this.fromMap) {
    var ref = this.fromMap[from];
    out.push([ref.from, ref.to]);
  }
  return out;
};
