var util = require('../util');
var Model = require('./Model');
var mutationEvents = require('./events').mutationEvents;
var ChangeEvent = mutationEvents.ChangeEvent;
var InsertEvent = mutationEvents.InsertEvent;
var RemoveEvent = mutationEvents.RemoveEvent;
var MoveEvent = mutationEvents.MoveEvent;
var promisify = util.promisify;

Model.prototype._mutate = function(segments, fn, cb) {
  cb = this.wrapCallback(cb);
  var collectionName = segments[0];
  var id = segments[1];
  if (!collectionName || !id) {
    var message = fn.name + ' must be performed under a collection ' +
      'and document id. Invalid path: ' + segments.join('.');
    return cb(new Error(message));
  }
  var doc = this.getOrCreateDoc(collectionName, id);
  var docSegments = segments.slice(2);
  if (this._preventCompose && doc.shareDoc) {
    var oldPreventCompose = doc.shareDoc.preventCompose;
    doc.shareDoc.preventCompose = true;
    var out = fn(doc, docSegments, cb);
    doc.shareDoc.preventCompose = oldPreventCompose;
    return out;
  }
  return fn(doc, docSegments, cb);
};

Model.prototype.set = function() {
  var subpath, value, cb;
  if (arguments.length === 1) {
    value = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    value = arguments[1];
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._set(segments, value, cb);
};
Model.prototype.setPromised = promisify(Model.prototype.set);

Model.prototype._set = function(segments, value, cb) {
  segments = this._dereference(segments);
  var model = this;
  function set(doc, docSegments, fnCb) {
    var previous = doc.set(docSegments, value, fnCb);
    // On setting the entire doc, remote docs sometimes do a copy to add the
    // id without it being stored in the database by ShareJS
    if (docSegments.length === 0) value = doc.get(docSegments);
    var event = new ChangeEvent(value, previous, model._pass);
    model._emitMutation(segments, event);
    return previous;
  }
  return this._mutate(segments, set, cb);
};

Model.prototype.setNull = function() {
  var subpath, value, cb;
  if (arguments.length === 1) {
    value = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    value = arguments[1];
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._setNull(segments, value, cb);
};
Model.prototype.setNullPromised = promisify(Model.prototype.setNull);

Model.prototype._setNull = function(segments, value, cb) {
  segments = this._dereference(segments);
  var model = this;
  function setNull(doc, docSegments, fnCb) {
    var previous = doc.get(docSegments);
    if (previous != null) {
      fnCb();
      return previous;
    }
    doc.set(docSegments, value, fnCb);
    var event = new ChangeEvent(value, previous, model._pass);
    model._emitMutation(segments, event);
    return value;
  }
  return this._mutate(segments, setNull, cb);
};

Model.prototype.setEach = function() {
  var subpath, object, cb;
  if (arguments.length === 1) {
    object = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    object = arguments[1];
  } else {
    subpath = arguments[0];
    object = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._setEach(segments, object, cb);
};
Model.prototype.setEachPromised = promisify(Model.prototype.setEach);

Model.prototype._setEach = function(segments, object, cb) {
  segments = this._dereference(segments);
  var group = util.asyncGroup(this.wrapCallback(cb));
  for (var key in object) {
    var value = object[key];
    this._set(segments.concat(key), value, group());
  }
};

Model.prototype.create = function() {
  var subpath, value, cb;
  if (arguments.length === 0) {
    value = {};
  } else if (arguments.length === 1) {
    if (typeof arguments[0] === 'function') {
      value = {};
      cb = arguments[0];
    } else {
      value = arguments[0];
    }
  } else if (arguments.length === 2) {
    if (typeof arguments[1] === 'function') {
      value = arguments[0];
      cb = arguments[1];
    } else {
      subpath = arguments[0];
      value = arguments[1];
    }
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._create(segments, value, cb);
};
Model.prototype.createPromised = promisify(Model.prototype.create);

Model.prototype._create = function(segments, value, cb) {
  segments = this._dereference(segments);
  if (segments.length !== 2) {
    var message = 'create may only be used on a document path. ' +
      'Invalid path: ' + segments.join('.');
    cb = this.wrapCallback(cb);
    return cb(new Error(message));
  }
  var model = this;
  function create(doc, docSegments, fnCb) {
    var previous;
    doc.create(value, fnCb);
    // On creating the doc, remote docs do a copy to add the id without
    // it being stored in the database by ShareJS
    value = doc.get();
    var event = new ChangeEvent(value, previous, model._pass);
    model._emitMutation(segments, event);
  }
  this._mutate(segments, create, cb);
};

Model.prototype.createNull = function() {
  var subpath, value, cb;
  if (arguments.length === 0) {
    value = {};
  } else if (arguments.length === 1) {
    if (typeof arguments[0] === 'function') {
      value = {};
      cb = arguments[0];
    } else {
      value = arguments[0];
    }
  } else if (arguments.length === 2) {
    if (typeof arguments[1] === 'function') {
      value = arguments[0];
      cb = arguments[1];
    } else {
      subpath = arguments[0];
      value = arguments[1];
    }
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._createNull(segments, value, cb);
};
Model.prototype.createNullPromised = promisify(Model.prototype.createNull);

Model.prototype._createNull = function(segments, value, cb) {
  segments = this._dereference(segments);
  var doc = this.getDoc(segments[0], segments[1]);
  if (doc && doc.get() != null) return;
  this._create(segments, value, cb);
};

Model.prototype.add = function() {
  var subpath, value, cb;
  if (arguments.length === 0) {
    value = {};
  } else if (arguments.length === 1) {
    if (typeof arguments[0] === 'function') {
      value = {};
      cb = arguments[0];
    } else {
      value = arguments[0];
    }
  } else if (arguments.length === 2) {
    if (typeof arguments[1] === 'function') {
      value = arguments[0];
      cb = arguments[1];
    } else {
      subpath = arguments[0];
      value = arguments[1];
    }
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._add(segments, value, cb);
};
Model.prototype.addPromised = promisify(Model.prototype.add);

Model.prototype._add = function(segments, value, cb) {
  if (typeof value !== 'object') {
    var message = 'add requires an object value. Invalid value: ' + value;
    cb = this.wrapCallback(cb);
    return cb(new Error(message));
  }
  var id = value.id || this.id();
  value.id = id;
  segments = this._dereference(segments.concat(id));
  var model = this;
  function add(doc, docSegments, fnCb) {
    var previous;
    if (docSegments.length) {
      previous = doc.set(docSegments, value, fnCb);
    } else {
      doc.create(value, fnCb);
      // On creating the doc, remote docs do a copy to add the id without
      // it being stored in the database by ShareJS
      value = doc.get();
    }
    var event = new ChangeEvent(value, previous, model._pass);
    model._emitMutation(segments, event);
  }
  this._mutate(segments, add, cb);
  return id;
};

Model.prototype.del = function() {
  var subpath, cb;
  if (arguments.length === 1) {
    if (typeof arguments[0] === 'function') {
      cb = arguments[0];
    } else {
      subpath = arguments[0];
    }
  } else {
    subpath = arguments[0];
    cb = arguments[1];
  }
  var segments = this._splitPath(subpath);
  return this._del(segments, cb);
};
Model.prototype.delPromised = promisify(Model.prototype.del);

Model.prototype._del = function(segments, cb) {
  segments = this._dereference(segments);
  return this._delNoDereference(segments, cb);
};
Model.prototype._delNoDereference = function(segments, cb) {
  var model = this;
  function del(doc, docSegments, fnCb) {
    var previous = doc.del(docSegments, fnCb);
    // When deleting an entire document, also remove the reference to the
    // document object from its collection
    if (segments.length === 2) {
      var collectionName = segments[0];
      var id = segments[1];
      model.root.collections[collectionName].remove(id);
    }
    var event = new ChangeEvent(undefined, previous, model._pass);
    model._emitMutation(segments, event);
    return previous;
  }
  return this._mutate(segments, del, cb);
};

Model.prototype.increment = function() {
  var subpath, byNumber, cb;
  if (arguments.length === 1) {
    if (typeof arguments[0] === 'function') {
      cb = arguments[0];
    } else if (typeof arguments[0] === 'number') {
      byNumber = arguments[0];
    } else {
      subpath = arguments[0];
    }
  } else if (arguments.length === 2) {
    if (typeof arguments[1] === 'function') {
      cb = arguments[1];
      if (typeof arguments[0] === 'number') {
        byNumber = arguments[0];
      } else {
        subpath = arguments[0];
      }
    } else {
      subpath = arguments[0];
      byNumber = arguments[1];
    }
  } else {
    subpath = arguments[0];
    byNumber = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._increment(segments, byNumber, cb);
};
Model.prototype.incrementPromised = promisify(Model.prototype.increment);

Model.prototype._increment = function(segments, byNumber, cb) {
  segments = this._dereference(segments);
  if (byNumber == null) byNumber = 1;
  var model = this;
  function increment(doc, docSegments, fnCb) {
    var value = doc.increment(docSegments, byNumber, fnCb);
    var previous = value - byNumber;
    var event = new ChangeEvent(value, previous, model._pass);
    model._emitMutation(segments, event);
    return value;
  }
  return this._mutate(segments, increment, cb);
};

Model.prototype.push = function() {
  var subpath, value, cb;
  if (arguments.length === 1) {
    value = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    value = arguments[1];
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._push(segments, value, cb);
};
Model.prototype.pushPromised = promisify(Model.prototype.push);

Model.prototype._push = function(segments, value, cb) {
  var forArrayMutator = true;
  segments = this._dereference(segments, forArrayMutator);
  var model = this;
  function push(doc, docSegments, fnCb) {
    var length = doc.push(docSegments, value, fnCb);
    var event = new InsertEvent(length - 1, [value], model._pass);
    model._emitMutation(segments, event);
    return length;
  }
  return this._mutate(segments, push, cb);
};

Model.prototype.unshift = function() {
  var subpath, value, cb;
  if (arguments.length === 1) {
    value = arguments[0];
  } else if (arguments.length === 2) {
    subpath = arguments[0];
    value = arguments[1];
  } else {
    subpath = arguments[0];
    value = arguments[1];
    cb = arguments[2];
  }
  var segments = this._splitPath(subpath);
  return this._unshift(segments, value, cb);
};
Model.prototype.unshiftPromised = promisify(Model.prototype.unshift);

Model.prototype._unshift = function(segments, value, cb) {
  var forArrayMutator = true;
  segments = this._dereference(segments, forArrayMutator);
  var model = this;
  function unshift(doc, docSegments, fnCb) {
    var length = doc.unshift(docSegments, value, fnCb);
    var event = new InsertEvent(0, [value], model._pass);
    model._emitMutation(segments, event);
    return length;
  }
  return this._mutate(segments, unshift, cb);
};

Model.prototype.insert = function() {
  var subpath, index, values, cb;
  if (arguments.length < 2) {
    throw new Error('Not enough arguments for insert');
  } else if (arguments.length === 2) {
    index = arguments[0];
    values = arguments[1];
  } else if (arguments.length === 3) {
    subpath = arguments[0];
    index = arguments[1];
    values = arguments[2];
  } else {
    subpath = arguments[0];
    index = arguments[1];
    values = arguments[2];
    cb = arguments[3];
  }
  var segments = this._splitPath(subpath);
  return this._insert(segments, +index, values, cb);
};
Model.prototype.insertPromised = promisify(Model.prototype.insert);

Model.prototype._insert = function(segments, index, values, cb) {
  var forArrayMutator = true;
  segments = this._dereference(segments, forArrayMutator);
  var model = this;
  function insert(doc, docSegments, fnCb) {
    var inserted = (Array.isArray(values)) ? values : [values];
    var length = doc.insert(docSegments, index, inserted, fnCb);
    var event = new InsertEvent(index, inserted, model._pass);
    model._emitMutation(segments, event);
    return length;
  }
  return this._mutate(segments, insert, cb);
};

Model.prototype.pop = function() {
  var subpath, cb;
  if (arguments.length === 1) {
    if (typeof arguments[0] === 'function') {
      cb = arguments[0];
    } else {
      subpath = arguments[0];
    }
  } else {
    subpath = arguments[0];
    cb = arguments[1];
  }
  var segments = this._splitPath(subpath);
  return this._pop(segments, cb);
};
Model.prototype.popPromised = promisify(Model.prototype.pop);

Model.prototype._pop = function(segments, cb) {
  var forArrayMutator = true;
  segments = this._dereference(segments, forArrayMutator);
  var model = this;
  function pop(doc, docSegments, fnCb) {
    var arr = doc.get(docSegments);
    var length = arr && arr.length;
    if (!length) {
      fnCb();
      return;
    }
    var value = doc.pop(docSegments, fnCb);
    var event = new RemoveEvent(length - 1, [value], model._pass);
    model._emitMutation(segments, event);
    return value;
  }
  return this._mutate(segments, pop, cb);
};

Model.prototype.shift = function() {
  var subpath, cb;
  if (arguments.length === 1) {
    if (typeof arguments[0] === 'function') {
      cb = arguments[0];
    } else {
      subpath = arguments[0];
    }
  } else {
    subpath = arguments[0];
    cb = arguments[1];
  }
  var segments = this._splitPath(subpath);
  return this._shift(segments, cb);
};
Model.prototype.shiftPromised = promisify(Model.prototype.shift);

Model.prototype._shift = function(segments, cb) {
  var forArrayMutator = true;
  segments = this._dereference(segments, forArrayMutator);
  var model = this;
  function shift(doc, docSegments, fnCb) {
    var arr = doc.get(docSegments);
    var length = arr && arr.length;
    if (!length) {
      fnCb();
      return;
    }
    var value = doc.shift(docSegments, fnCb);
    var event = new RemoveEvent(0, [value], model._pass);
    model._emitMutation(segments, event);
    return value;
  }
  return this._mutate(segments, shift, cb);
};

Model.prototype.remove = function() {
  var subpath, index, howMany, cb;
  if (arguments.length < 2) {
    index = arguments[0];
  } else if (arguments.length === 2) {
    if (typeof arguments[1] === 'function') {
      cb = arguments[1];
      if (typeof arguments[0] === 'number') {
        index = arguments[0];
      } else {
        subpath = arguments[0];
      }
    } else {
      // eslint-disable-next-line no-lonely-if
      if (typeof arguments[0] === 'number') {
        index = arguments[0];
        howMany = arguments[1];
      } else {
        subpath = arguments[0];
        index = arguments[1];
      }
    }
  } else if (arguments.length === 3) {
    if (typeof arguments[2] === 'function') {
      cb = arguments[2];
      if (typeof arguments[0] === 'number') {
        index = arguments[0];
        howMany = arguments[1];
      } else {
        subpath = arguments[0];
        index = arguments[1];
      }
    } else {
      subpath = arguments[0];
      index = arguments[1];
      howMany = arguments[2];
    }
  } else {
    subpath = arguments[0];
    index = arguments[1];
    howMany = arguments[2];
    cb = arguments[3];
  }
  var segments = this._splitPath(subpath);
  if (index == null) index = segments.pop();
  return this._remove(segments, +index, howMany, cb);
};
Model.prototype.removePromised = promisify(Model.prototype.remove);

Model.prototype._remove = function(segments, index, howMany, cb) {
  var forArrayMutator = true;
  segments = this._dereference(segments, forArrayMutator);
  if (howMany == null) howMany = 1;
  var model = this;
  function remove(doc, docSegments, fnCb) {
    var removed = doc.remove(docSegments, index, howMany, fnCb);
    var event = new RemoveEvent(index, removed, model._pass);
    model._emitMutation(segments, event);
    return removed;
  }
  return this._mutate(segments, remove, cb);
};

Model.prototype.move = function() {
  var subpath, from, to, howMany, cb;
  if (arguments.length < 2) {
    throw new Error('Not enough arguments for move');
  } else if (arguments.length === 2) {
    from = arguments[0];
    to = arguments[1];
  } else if (arguments.length === 3) {
    if (typeof arguments[2] === 'function') {
      from = arguments[0];
      to = arguments[1];
      cb = arguments[2];
    } else if (typeof arguments[0] === 'number') {
      from = arguments[0];
      to = arguments[1];
      howMany = arguments[2];
    } else {
      subpath = arguments[0];
      from = arguments[1];
      to = arguments[2];
    }
  } else if (arguments.length === 4) {
    if (typeof arguments[3] === 'function') {
      cb = arguments[3];
      if (typeof arguments[0] === 'number') {
        from = arguments[0];
        to = arguments[1];
        howMany = arguments[2];
      } else {
        subpath = arguments[0];
        from = arguments[1];
        to = arguments[2];
      }
    } else {
      subpath = arguments[0];
      from = arguments[1];
      to = arguments[2];
      howMany = arguments[3];
    }
  } else {
    subpath = arguments[0];
    from = arguments[1];
    to = arguments[2];
    howMany = arguments[3];
    cb = arguments[4];
  }
  var segments = this._splitPath(subpath);
  return this._move(segments, from, to, howMany, cb);
};
Model.prototype.movePromised = promisify(Model.prototype.move);

Model.prototype._move = function(segments, from, to, howMany, cb) {
  var forArrayMutator = true;
  segments = this._dereference(segments, forArrayMutator);
  if (howMany == null) howMany = 1;
  var model = this;
  function move(doc, docSegments, fnCb) {
    // Cast to numbers
    from = +from;
    to = +to;
    // Convert negative indices into positive
    if (from < 0 || to < 0) {
      var len = doc.get(docSegments).length;
      if (from < 0) from += len;
      if (to < 0) to += len;
    }
    var moved = doc.move(docSegments, from, to, howMany, fnCb);
    var event = new MoveEvent(from, to, moved.length, model._pass);
    model._emitMutation(segments, event);
    return moved;
  }
  return this._mutate(segments, move, cb);
};

Model.prototype.stringInsert = function() {
  var subpath, index, text, cb;
  if (arguments.length < 2) {
    throw new Error('Not enough arguments for stringInsert');
  } else if (arguments.length === 2) {
    index = arguments[0];
    text = arguments[1];
  } else if (arguments.length === 3) {
    if (typeof arguments[2] === 'function') {
      index = arguments[0];
      text = arguments[1];
      cb = arguments[2];
    } else {
      subpath = arguments[0];
      index = arguments[1];
      text = arguments[2];
    }
  } else {
    subpath = arguments[0];
    index = arguments[1];
    text = arguments[2];
    cb = arguments[3];
  }
  var segments = this._splitPath(subpath);
  return this._stringInsert(segments, index, text, cb);
};
Model.prototype.stringInsertPromised = promisify(Model.prototype.stringInsert);

Model.prototype._stringInsert = function(segments, index, text, cb) {
  segments = this._dereference(segments);
  var model = this;
  function stringInsert(doc, docSegments, fnCb) {
    var previous = doc.stringInsert(docSegments, index, text, fnCb);
    var value = doc.get(docSegments);
    var pass = model.pass({$stringInsert: {index: index, text: text}})._pass;
    var event = new ChangeEvent(value, previous, pass);
    model._emitMutation(segments, event);
    return;
  }
  return this._mutate(segments, stringInsert, cb);
};

Model.prototype.stringRemove = function() {
  var subpath, index, howMany, cb;
  if (arguments.length < 2) {
    throw new Error('Not enough arguments for stringRemove');
  } else if (arguments.length === 2) {
    index = arguments[0];
    howMany = arguments[1];
  } else if (arguments.length === 3) {
    if (typeof arguments[2] === 'function') {
      index = arguments[0];
      howMany = arguments[1];
      cb = arguments[2];
    } else {
      subpath = arguments[0];
      index = arguments[1];
      howMany = arguments[2];
    }
  } else {
    subpath = arguments[0];
    index = arguments[1];
    howMany = arguments[2];
    cb = arguments[3];
  }
  var segments = this._splitPath(subpath);
  return this._stringRemove(segments, index, howMany, cb);
};
Model.prototype.stringRemovePromised = promisify(Model.prototype.stringRemove);

Model.prototype._stringRemove = function(segments, index, howMany, cb) {
  segments = this._dereference(segments);
  var model = this;
  function stringRemove(doc, docSegments, fnCb) {
    var previous = doc.stringRemove(docSegments, index, howMany, fnCb);
    var value = doc.get(docSegments);
    var pass = model.pass({$stringRemove: {index: index, howMany: howMany}})._pass;
    var event = new ChangeEvent(value, previous, pass);
    model._emitMutation(segments, event);
    return;
  }
  return this._mutate(segments, stringRemove, cb);
};

Model.prototype.subtypeSubmit = function() {
  var subpath, subtype, subtypeOp, cb;
  if (arguments.length < 2) {
    throw new Error('Not enough arguments for subtypeSubmit');
  } else if (arguments.length === 2) {
    subtype = arguments[0];
    subtypeOp = arguments[1];
  } else if (arguments.length === 3) {
    if (typeof arguments[2] === 'function') {
      subtype = arguments[0];
      subtypeOp = arguments[1];
      cb = arguments[2];
    } else {
      subpath = arguments[0];
      subtype = arguments[1];
      subtypeOp = arguments[2];
    }
  } else {
    subpath = arguments[0];
    subtype = arguments[1];
    subtypeOp = arguments[2];
    cb = arguments[3];
  }
  var segments = this._splitPath(subpath);
  return this._subtypeSubmit(segments, subtype, subtypeOp, cb);
};
Model.prototype.subtypeSubmitPromised = promisify(Model.prototype.subtypeSubmit);

Model.prototype._subtypeSubmit = function(segments, subtype, subtypeOp, cb) {
  segments = this._dereference(segments);
  var model = this;
  function subtypeSubmit(doc, docSegments, fnCb) {
    var previous = doc.subtypeSubmit(docSegments, subtype, subtypeOp, fnCb);
    var value = doc.get(docSegments);
    var pass = model.pass({$subtype: {type: subtype, op: subtypeOp}})._pass;
    // Emit undefined for the previous value, since we don't really know
    // whether or not the previous value returned by the subtypeSubmit is the
    // same object returned by reference or not. This may cause change
    // listeners to over-trigger, but that is usually going to be better than
    // under-triggering
    var event = new ChangeEvent(value, undefined, pass);
    model._emitMutation(segments, event);
    return previous;
  }
  return this._mutate(segments, subtypeSubmit, cb);
};
