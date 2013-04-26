var racer = require('../racer');
var Model = require('./index');
var Refs = require('./Refs');

racer.on('Model:init', function(model) {
  model._refs = new Refs;
  for (var type in Model.MUTATOR_EVENTS) {
    addRefListener(model, type);
  }
});

function addRefListener(model, type) {
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
  this._refs.add(from, to);
};

Model.prototype.removeRef = function(from) {
  this._refs.remove(from);
};
