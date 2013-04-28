var Model = require('./index');
var util = require('../util');

Model.prototype._resolvePath = function(subpath) {
  var path = this.path(subpath);
  var segments = path.split('.');
  return this._dereferenceSegments(segments);
};

Model.prototype._defaultCallback = function() {
  var model = this;
  function defaultCallback(err) {
    if (err) model.emit('error', err);
  }
  this._defaultCallback = function() {
    return defaultCallback;
  };
  return defaultCallback;
};

Model.prototype._mutate = function(subpath, fn, cb) {
  if (!cb) cb = this._defaultCallback();
  var segments = this._resolvePath(subpath);
  var collectionName = segments[0];
  var id = segments[1];
  if (!collectionName || !id) {
    var message = fn.name + ' must be performed under a collection ' +
      'and document id. Invalid path: ' +
      segments.join('.');
    var err = new Error(message);
    return cb(err);
  }
  var doc = this.getOrCreateDoc(collectionName, id);
  return fn(doc, segments, cb);
};

Model.prototype.add = function(subpath, value, cb) {
  if (!cb) cb = this._defaultCallback();
  var segments = this._resolvePath(subpath);
  var collectionName = segments[0];
  if (!collectionName || segments.length !== 1) {
    var message = 'add must be performed on a collection. Invaid path: ' +
      segments.join('.');
    var err = new Error(message);
    return cb(err);
  }
  if (typeof value !== 'object') {
    var message = 'add requires an object value. Invalid value: ' + value;
    var err = new Error(message);
    return cb(err);
  }
  var id = value.id || this.id();
  value.id = id;
  var doc = this.getOrCreateDoc(collectionName, id);
  var previous = doc.set([], value, cb);
  this.emit('change', [collectionName, id], [value, previous, true, this._pass]);
  return id;
};

Model.prototype.set = function(subpath, value, cb) {
  var model = this;
  function set(doc, segments, fnCb) {
    var previous = doc.set(segments.slice(2), value, fnCb);
    model.emit('change', segments, [value, previous, true, model._pass]);
    return previous;
  }
  return this._mutate(subpath, set, cb);
};

Model.prototype.setEach = function(subpath, object, cb) {
  // For Model#setEach(object, cb)
  if (subpath && typeof subpath === 'object') {
    cb = object;
    object = subpath;
    subpath = '';
  }
  var group = new util.AsyncGroup(cb || this._defaultCallback());
  for (var key in object) {
    var value = object[key];
    if (subpath) key = subpath + '.' + key;
    this.set(key, value, group.add());
  }
};

Model.prototype.setNull = function(subpath, value, cb) {
  var model = this;
  function setNull(doc, segments, fnCb) {
    var docSegments = segments.slice(2);
    var previous = doc.get(docSegments);
    if (previous != null) {
      fnCb();
      return previous;
    }
    doc.set(docSegments, value, fnCb);
    model.emit('change', segments, [value, previous, true, model._pass]);
    return value;
  }
  return this._mutate(subpath, setNull, cb);
};

Model.prototype.del = function(subpath, cb) {
  var model = this;
  function del(doc, segments, fnCb) {
    var previous = doc.del(segments.slice(2), fnCb);
    model.emit('change', segments, [void 0, previous, true, model._pass]);
    return previous;
  }
  return this._mutate(subpath, del, cb);
};

Model.prototype.increment = function(subpath, byNumber, cb) {
  if (byNumber == null) byNumber = 1;
  var model = this;
  function increment(doc, segments, fnCb) {
    var value = doc.increment(segments.slice(2), byNumber, fnCb);
    var previous = value - byNumber;
    model.emit('change', segments, [value, previous, true, model._pass]);
    return value;
  }
  return this._mutate(subpath, increment, cb);
};

Model.prototype.push = function(subpath, value, cb) {
  var model = this;
  function push(doc, segments, fnCb) {
    var length = doc.push(segments.slice(2), value, fnCb);
    model.emit('insert', segments, [length - 1, [value], true, model._pass]);
    return length;
  }
  return this._mutate(subpath, push, cb);
}

Model.prototype.unshift = function(subpath, value, cb) {
  var model = this;
  function unshift(doc, segments, fnCb) {
    var length = doc.unshift(segments.slice(2), value, fnCb);
    model.emit('insert', segments, [0, [value], true, model._pass]);
    return length;
  }
  return this._mutate(subpath, unshift, cb);
}

Model.prototype.insert = function(subpath, index, values, cb) {
  var model = this;
  function insert(doc, segments, fnCb) {
    var inserted = (Array.isArray(values)) ? values : [values];
    doc.insert(segments.slice(2), index, inserted, fnCb);
    model.emit('insert', segments, [index, inserted, true, model._pass]);
    return;
  }
  return this._mutate(subpath, insert, cb);
}

Model.prototype.pop = function(subpath, cb) {
  var model = this;
  function pop(doc, segments, fnCb) {
    var docSegments = segments.slice(2);
    var arr = doc.get(docSegments);
    var length = arr && arr.length;
    if (!length) {
      fnCb();
      return;
    }
    var value = doc.pop(docSegments, fnCb);
    model.emit('remove', segments, [length - 1, [value], true, model._pass]);
    return value;
  }
  return this._mutate(subpath, pop, cb);
}

Model.prototype.shift = function(subpath, cb) {
  var model = this;
  function shift(doc, segments, fnCb) {
    var docSegments = segments.slice(2);
    var arr = doc.get(docSegments);
    var length = arr && arr.length;
    if (!length) {
      fnCb();
      return;
    }
    var value = doc.shift(docSegments, fnCb);
    model.emit('remove', segments, [0, [value], true, model._pass]);
    return value;
  }
  return this._mutate(subpath, shift, cb);
}

Model.prototype.remove = function(subpath, index, howMany, cb) {
  if (howMany == null) howMany = 1;
  var model = this;
  function remove(doc, segments, fnCb) {
    var removed = doc.remove(segments.slice(2), index, howMany, fnCb);
    model.emit('remove', segments, [index, removed, true, model._pass]);
    return removed;
  }
  return this._mutate(subpath, remove, cb);
}

Model.prototype.move = function(subpath, from, to, howMany, cb) {
  if (howMany == null) howMany = 1;
  var model = this;
  function move(doc, segments, fnCb) {
    var moved = doc.move(segments.slice(2), from, to, howMany, fnCb);
    model.emit('move', segments, [from, to, moved.length, true, model._pass]);
    return moved;
  }
  return this._mutate(subpath, move, cb);
}

Model.prototype.stringInsert = function(subpath, index, value, cb) {
  var model = this;
  function stringInsert(doc, segments, fnCb) {
    doc.stringInsert(segments.slice(2), index, value, fnCb);
    model.emit('stringInsert', segments, [index, value, true, model._pass]);
    return;
  }
  return this._mutate(subpath, stringInsert, cb);
}

Model.prototype.stringRemove = function(subpath, index, howMany, cb) {
  var model = this;
  function stringRemove(doc, segments, fnCb) {
    doc.stringRemove(segments.slice(2), index, howMany, fnCb);
    model.emit('stringRemove', segments, [index, howMany, true, model._pass]);
    return;
  }
  return this._mutate(subpath, stringRemove, cb);
}
