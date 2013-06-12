/**
 * RemoteDoc adapts the ShareJS operation protocol to Racer's mutator
 * interface.
 *
 * 1. It maps Racer's mutator methods to outgoing ShareJS operations.
 * 2. It maps incoming ShareJS operations to Racer events.
 */

var Doc = require('./Doc');

module.exports = RemoteDoc;

function RemoteDoc(collectionName, id, data, model) {
  Doc.call(this, collectionName, id);
  var shareDoc = this.shareDoc = model._getOrCreateShareDoc(collectionName, id, data);
  this.model = model = model.pass({$remote: true});
  this._passStringInsert = model.pass({$original: 'stringInsert'})._pass;
  this._passStringRemove = model.pass({$original: 'stringRemove'})._pass;

  var doc = this;
  shareDoc.on('op', function(op, isLocal) {
    // Don't emit on local operations, since they are emitted in the mutator
    if (isLocal) return;
    doc._onOp(op);
  });
  shareDoc.on('del', function(isLocal, previous) {
    // Calling the shareDoc.del method does not emit an operation event,
    // so we create the appropriate event here.
    if (isLocal) return;
    model.emit('change', [collectionName, id], [void 0, previous, model._pass]);
  });
  shareDoc.on('create', function(isLocal) {
    // Local creates should not emit an event, since they only happen
    // implicitly as a result of another mutation, and that operation will
    // emit the appropriate event. Remote creates can set the snapshot data
    // without emitting an operation event, so an event needs to be emitted
    // for them.
    if (isLocal) return;
    var value = shareDoc.snapshot;
    model.emit('change', [collectionName, id], [value, void 0, model._pass]);
  });
}

RemoteDoc.prototype = new Doc;

RemoteDoc.prototype.set = function(segments, value, cb) {
  var previous = this._createImplied(segments);
  var lastSegment = segments[segments.length - 1];
  var op = (isArrayIndex(lastSegment)) ?
    (previous == null) ?
      [new ListInsertOp(segments.slice(0, -1), lastSegment, value)] :
      [new ListReplaceOp(segments.slice(0, -1), lastSegment, previous, value)] :
    (previous == null) ?
      [new ObjectInsertOp(segments, value)] :
      [new ObjectReplaceOp(segments, previous, value)];
  this.shareDoc.submitOp(op, cb);
  return previous;
};

RemoteDoc.prototype.del = function(segments, cb) {
  if (segments.length === 0) {
    var previous = this.get();
    this.shareDoc.del();
    cb();
    return previous;
  }
  // Don't do anything if the value is already undefined, since
  // the del method should not create anything
  var previous = this.get(segments);
  if (previous === void 0) {
    cb();
    return;
  }
  var op = [new ObjectDeleteOp(segments, previous)];
  this.shareDoc.submitOp(op, cb);
  return previous;
};

RemoteDoc.prototype.increment = function(segments, byNumber, cb) {
  var previous = this._createImplied(segments);
  if (previous == null) {
    var lastSegment = segments[segments.length - 1];
    var op = (isArrayIndex(lastSegment)) ?
      [new ListInsertOp(segments.slice(0, -1), lastSegment, byNumber)] :
      [new ObjectInsertOp(segments, byNumber)];
    this.shareDoc.submitOp(op, cb);
    return byNumber;
  }
  var op = [new IncrementOp(segments, byNumber)];
  this.shareDoc.submitOp(op, cb);
  return previous + byNumber;
};

RemoteDoc.prototype.push = function(segments, value, cb) {
  var shareDoc = this.shareDoc;
  function push(arr, fnCb) {
    var op = [new ListInsertOp(segments, arr.length, value)];
    shareDoc.submitOp(op, fnCb);
    return arr.length;
  }
  return this._arrayApply(segments, push, cb);
};

RemoteDoc.prototype.unshift = function(segments, value, cb) {
  var shareDoc = this.shareDoc;
  function unshift(arr, fnCb) {
    var op = [new ListInsertOp(segments, 0, value)];
    shareDoc.submitOp(op, fnCb);
    return arr.length;
  }
  return this._arrayApply(segments, unshift, cb);
};

RemoteDoc.prototype.insert = function(segments, index, values, cb) {
  var shareDoc = this.shareDoc;
  function insert(arr, fnCb) {
    var op = (Array.isArray(values)) ?
      eachOp(ListInsertOp, segments, index, values) :
      [new ListInsertOp(segments, index, values)];
    shareDoc.submitOp(op, fnCb);
    return arr.length;
  }
  return this._arrayApply(segments, insert, cb);
};

RemoteDoc.prototype.pop = function(segments, cb) {
  var shareDoc = this.shareDoc;
  function pop(arr, fnCb) {
    var index = arr.length - 1;
    var value = arr[index];
    var op = [new ListRemoveOp(segments, index, value)];
    shareDoc.submitOp(op, fnCb);
    return value;
  }
  return this._arrayApply(segments, pop, cb);
};

RemoteDoc.prototype.shift = function(segments, cb) {
  var shareDoc = this.shareDoc;
  function shift(arr, fnCb) {
    var value = arr[0];
    var op = [new ListRemoveOp(segments, 0, value)];
    shareDoc.submitOp(op, fnCb);
    return value;
  }
  return this._arrayApply(segments, shift, cb);
};

RemoteDoc.prototype.remove = function(segments, index, howMany, cb) {
  var shareDoc = this.shareDoc;
  function remove(arr, fnCb) {
    var values = arr.slice(index, index + howMany);
    var op = eachOp(ListRemoveOp, segments, index, values);
    shareDoc.submitOp(op, fnCb);
    return values;
  }
  return this._arrayApply(segments, remove, cb);
};

function eachOp(Constructor, segments, index, values) {
  var op = [];
  for (var i = 0, len = values.length; i < len; i++) {
    op.push(new Constructor(segments, index++, values[i]));
  }
  return op;
}

RemoteDoc.prototype.move = function(segments, from, to, howMany, cb) {
  var shareDoc = this.shareDoc;
  function move(arr, fnCb) {
    // Get the return value
    var values = arr.slice(from, from + howMany);

    // Build an op that moves each item individually
    var op = [];
    for (var i = howMany; i--;) {
      op.push(new ListMoveOp(segments, from++, to++));
    }
    shareDoc.submitOp(op, fnCb);

    return values;
  }
  return this._arrayApply(segments, move, cb);
};

RemoteDoc.prototype.stringInsert = function(segments, index, value, cb) {
  var previous = this._createImplied(segments);
  if (previous == null) {
    var lastSegment = segments[segments.length - 1];
    var op = (isArrayIndex(lastSegment)) ?
      [new ListInsertOp(segments.slice(0, -1), lastSegment, value)] :
      [new ObjectInsertOp(segments, value)];
    this.shareDoc.submitOp(op, cb);
    return previous;
  }
  var op = [new StringInsertOp(segments, index, value)];
  this.shareDoc.submitOp(op, cb);
  return previous;
};

RemoteDoc.prototype.stringRemove = function(segments, index, howMany, cb) {
  var previous = this._createImplied(segments);
  if (previous == null) return previous;
  var removed = previous.slice(index, index + howMany);
  var op = [new StringRemoveOp(segments, index, removed)];
  this.shareDoc.submitOp(op, cb);
  return previous;
};

RemoteDoc.prototype.get = function(segments) {
  return this._get(this.shareDoc.snapshot, segments);
};

RemoteDoc.prototype._createImplied = function(segments) {
  if (!this.shareDoc.type) {
    this.shareDoc.create('json0', this.model._defaultCallback);
  }
  var parent = this.shareDoc;
  var key = 'snapshot';
  var node = parent[key];
  var i = 0;
  var nextKey = segments[i++];
  while (nextKey != null) {
    if (!node) {
      var value = isArrayIndex(nextKey) ? [] : {};
      var op = (Array.isArray(parent)) ?
        new ListInsertOp(segments.slice(0, i - 2), key, value) :
        new ObjectInsertOp(segments.slice(0, i - 1), value);
      this.shareDoc.submitOp(op);
      node = parent[key];
    }
    parent = node;
    key = nextKey;
    node = parent[key];
    nextKey = segments[i++];
  }
  return node;
};

RemoteDoc.prototype._arrayApply = function(segments, fn, cb) {
  var arr = this._createImplied(segments);
  if (arr == null) {
    var lastSegment = segments[segments.length - 1];
    var op = (isArrayIndex(lastSegment)) ?
      [new ListInsertOp(segments.slice(0, -1), lastSegment, [])] :
      [new ObjectInsertOp(segments, [])];
    this.shareDoc.submitOp(op);
    arr = this.get(segments);
  }

  if (!Array.isArray(arr)) {
    var message = this._errorMessage(fn.name + ' on non-array', segments, arr);
    var err = new TypeError(message);
    return cb(err);
  }
  return fn(arr, cb);
};

RemoteDoc.prototype._onOp = function(op) {
  var item = op[0];
  var segments = [this.collectionName, this.id].concat(item.p);
  var model = this.model;

  // ObjectReplaceOp, ObjectInsertOp, or ObjectDeleteOp
  if (defined(item.oi) || defined(item.od)) {
    var value = item.oi;
    var previous = item.od;
    model.emit('change', segments, [value, previous, model._pass]);

  // ListReplaceOp
  } else if (defined(item.li) && defined(item.ld)) {
    var value = item.li;
    var previous = item.ld;
    model.emit('change', segments, [value, previous, model._pass]);

  // ListInsertOp
  } else if (defined(item.li)) {
    var index = segments[segments.length - 1];
    var values = [item.li];
    model.emit('insert', segments.slice(0, -1), [index, values, model._pass]);

  // ListRemoveOp
  } else if (defined(item.ld)) {
    var index = segments[segments.length - 1];
    var removed = [item.ld];
    model.emit('remove', segments.slice(0, -1), [index, removed, model._pass]);

  // ListMoveOp
  } else if (defined(item.lm)) {
    var from = segments[segments.length - 1];
    var to = item.lm;
    var howMany = 1;
    model.emit('move', segments.slice(0, -1), [from, to, howMany, model._pass]);

  // StringInsertOp
  } else if (defined(item.si)) {
    var index = segments[segments.length - 1];
    var text = item.si;
    segments = segments.slice(0, -1);
    model.emit('stringInsert', segments, [index, text, model._pass]);
    var value = model._get(segments);
    var previous = value.slice(0, index) + value.slice(index + text.length);
    model.emit('change', segments, [value, previous, this._passStringInsert]);

  // StringRemoveOp
  } else if (defined(item.sd)) {
    var index = segments[segments.length - 1];
    var text = item.sd;
    var howMany = text.length;
    segments = segments.slice(0, -1);
    model.emit('stringRemove', segments, [index, howMany, model._pass]);
    var value = model._get(segments);
    var previous = value.slice(0, index) + text + value.slice(index);
    model.emit('change', segments, [value, previous, this._passStringRemove]);

  // IncrementOp
  } else if (defined(item.na)) {
    var value = this.get(item.p);
    var previous = value - item.na;
    model.emit('change', segments, [value, previous, model._pass]);
  }
};

function ObjectReplaceOp(segments, before, after) {
  this.p = castSegments(segments);
  this.od = before;
  this.oi = after;
}
function ObjectInsertOp(segments, value) {
  this.p = castSegments(segments);
  this.oi = value;
}
function ObjectDeleteOp(segments, value) {
  this.p = castSegments(segments);
  this.od = value;
}
function ListReplaceOp(segments, index, before, after) {
  this.p = castSegments(segments.concat(index));
  this.ld = before;
  this.li = after;
}
function ListInsertOp(segments, index, value) {
  this.p = castSegments(segments.concat(index));
  this.li = value;
}
function ListRemoveOp(segments, index, value) {
  this.p = castSegments(segments.concat(index));
  this.ld = value;
}
function ListMoveOp(segments, from, to) {
  this.p = castSegments(segments.concat(from));
  this.lm = to;
}
function StringInsertOp(segments, index, value) {
  this.p = castSegments(segments.concat(index));
  this.si = value;
}
function StringRemoveOp(segments, index, value) {
  this.p = castSegments(segments.concat(index));
  this.sd = value;
}
function IncrementOp(segments, byNumber) {
  this.p = castSegments(segments);
  this.na = byNumber;
}

function defined(value) {
  return value !== void 0;
}

function castSegments(segments) {
  // Cast number path segments from strings to numbers
  for (var i = segments.length; i--;) {
    var segment = segments[i];
    if (typeof segment === 'string' && isArrayIndex(segment)) {
      segments[i] = +segment;
    }
  }
  return segments;
}

function isArrayIndex(segment) {
  return (/^[0-9]+$/).test(segment);
}
