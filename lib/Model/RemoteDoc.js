module.exports = RemoteDoc;

function RemoteDoc(collectionName, id, shareDoc, emitter) {
  this.collectionName = collectionName;
  this.id = id;
  this.shareDoc = shareDoc;
  this.emitter = emitter;
  if (emitter) shareDoc.on('op', onOp.bind(this));
}

RemoteDoc.prototype.path = function(segments) {
  return this.collectionName + '.' + this.id + '.' + segments.join('.');
};

RemoteDoc.prototype.set = function(segments, value, cb) {
  var previous = this._createImplied(segments);
  var op = (previous == null) ?
    [new ObjectInsertOp(segments, value)] :
    [new ObjectReplaceOp(segments, previous, value)];
  this.shareDoc.submitOp(op, cb);
  return previous;
};

RemoteDoc.prototype.del = function(segments, cb) {
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
  var op = [new IncrementOp(segments, byNumber)];
  this.shareDoc.submitOp(op, cb);
  return previous + byNumber;
};

RemoteDoc.prototype.push = function(segments, value, cb) {
  var shareDoc = this.shareDoc;
  function push(arr, fnCb) {
    var op = [new ListInsertOp(segments, arr.length, value)]
    shareDoc.submitOp(op, fnCb);
    return arr.length;
  }
  return this._arrayApply(segments, push, cb);
};

RemoteDoc.prototype.unshift = function(segments, value, cb) {
  var shareDoc = this.shareDoc;
  function unshift(arr, fnCb) {
    var op = [new ListInsertOp(segments, 0, value)]
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
    return;
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
    var values = arr.slice(index, howMany);
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
    var len = arr.length;
    // Cast to numbers
    from = +from;
    to = +to;
    // Make sure indices are positive
    if (from < 0) from += len;
    if (to < 0) to += len;

    // Get the return value
    var values = arr.slice(from, howMany);

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
    var op = [new ObjectInsertOp(segments, value)];
    this.shareDoc.submitOp(op, cb);
    return;
  }
  var op = [new StringInsertOp(segments, index, value)];
  this.shareDoc.submitOp(op, cb)
  return;
};

RemoteDoc.prototype.stringRemove = function(segments, index, howMany, cb) {
  var previous = this._createImplied(segments);
  if (previous == null) return;
  var op = [new StringRemoveOp(segments, index, removed)];
  this.shareDoc.submitOp(op, cb);
  return;
};

RemoteDoc.prototype.get = function(segments) {
  if (!segments) return this.shareDoc.snapshot;
  var node = this.shareDoc.snapshot;
  var i = 0;
  var key;
  while (key = segments[i++]) {
    if (node == null) return;
    node = node[key];
  }
  return node;
};

RemoteDoc.prototype._createImplied = function(segments) {
  var parent = this.shareDoc;
  var key = 'snapshot';
  var node = parent[key];
  var i = 0;
  var nextKey;
  while (nextKey = segments[i++]) {
    if (!node) {
      var value = /^\d+$/.test(nextKey) ? [] : {};
      var op = [new ObjectInsertOp(segments.slice(0, i - 1), value)];
      this.shareDoc.submitOp(op);
      node = parent[key];
    }
    parent = node;
    key = nextKey;
    node = parent[key];
  }
  return node;
};

RemoteDoc.prototype._arrayApply = function(segments, fn, cb) {
  var arr = this._createImplied(segments);
  if (!arr) {
    arr = [];
    var op = [new ObjectInsertOp(segments, arr)];
    this.shareDoc.submitOp(op);
  }

  if (!Array.isArray(arr)) {
    var message = this._errorMessage(fn.name + ' on non-array', segments, arr);
    var err = new TypeError(message);
    return cb(err);
  }
  return fn(arr, cb);
};

RemoteDoc.prototype._errorMessage = function(description, segments, value) {
  return description + ' at ' + this.path(segments) + ': ' +
    JSON.stringify(value, null, 2);
};

function ObjectReplaceOp(segments, before, after) {
  this.p = segments;
  this.od = before;
  this.oi = after;
}
function ObjectInsertOp(segments, value) {
  this.p = segments;
  this.oi = value;
}
function ObjectDeleteOp(segments, value) {
  this.p = segments;
  this.od = value;
}
function ListReplaceOp(segments, index, before, after) {
  this.p = segments.concat(index);
  this.ld = before;
  this.li = after;
}
function ListInsertOp(segments, index, value) {
  this.p = segments.concat(index);
  this.li = value;
}
function ListRemoveOp(segments, index, value) {
  this.p = segments.concat(index);
  this.ld = value;
}
function ListMoveOp(segments, from, to) {
  this.p = segments.concat(from);
  this.lm = to;
}
function StringInsertOp(segments, index, value) {
  this.p = segments.concat(index);
  this.si = value;
}
function StringRemoveOp(segments, index, value) {
  this.p = segments.concat(index);
  this.sd = value;
}
function IncrementOp(segments, byNumber) {
  this.p = segments;
  this.na = byNumber;
}

function onOp(op, isLocal) {
  // Don't emit on local operations, since they are emitted in the mutator
  if (isLocal) return;

  var item = op[0];
  var segments = [this.collectionName, this.id].concat(item.p);
  var emitter = this.emitter;

  // ObjectReplaceOp, ObjectInsertOp, or ObjectDeleteOp
  if (defined(item.oi) || defined(item.od)) {
    var value = item.oi;
    var previous = item.od;
    emitter.emit('change', segments, value, previous, isLocal);

  // ListReplaceOp
  } else if (defined(item.li) && defined(item.ld)) {
    var value = item.li;
    var previous = item.ld;
    emitter.emit('change', segments, value, previous, isLocal);

  // ListInsertOp
  } else if (defined(item.li)) {
    var index = segments[segments.length - 1];
    var values = [item.li];
    emitter.emit('insert', segments.slice(0, -1), index, values, isLocal);

  // ListRemoveOp
  } else if (defined(item.ld)) {
    var index = segments[segments.length - 1];
    var removed = item.ld;
    emitter.emit('remove', segments.slice(0, -1), index, removed, isLocal);

  // ListMoveOp
  } else if (defined(item.lm)) {
    var from = segments[segments.length - 1];
    var to = item.lm;
    var howMany = 1;
    emitter.emit('move', segments.slice(0, -1), from, to, howMany, isLocal);

  // StringInsertOp
  } else if (defined(item.si)) {
    var index = segments[segments.length - 1];
    var value = item.si;
    emitter.emit('stringInsert', segments, index, value, isLocal);

  // StringRemoveOp
  } else if (defined(item.sd)) {
    var index = segments[segments.length - 1];
    var howMany = item.sd.length;
    emitter.emit('stringRemove', segments, index, howMany, isLocal);

  // IncrementOp
  } else if (defined(item.na)) {
    var value = this.get(segments);
    var previous = value - item.na;
    emitter.emit('change', segments, value, previous, isLocal);
  }
}

function defined(value) {
  return value !== void 0;
}
