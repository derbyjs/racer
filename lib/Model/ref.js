var racer = require('../racer');
var Model = require('./index');

racer.on('Model:init', function(model) {
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

Model.prototype.ref = function(from, to) {
  from = this.path(from);
  to = this.path(to);
  this._refs.add(from, to);
};

Model.prototype.removeRef = function(from) {
  from = this.path(from);
  this._refs.remove(from);
};

Model.prototype._dereferenceSegments = function(segments) {
  var fromMap = this._refs.fromMap;
  do {
    var subpath = '';
    var doAgain = false;
    for (var i = 0, len = segments.length; i < len; i++) {
      subpath = (subpath) ? subpath + '.' + segments[i] : segments[i];
      var ref = fromMap[subpath];
      if (!ref) continue;
      var remaining = segments.slice(i + 1);
      segments = ref.toSegments.concat(remaining);
      doAgain = true;
      break;
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
