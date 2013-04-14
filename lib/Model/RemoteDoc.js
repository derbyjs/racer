module.exports = RemoteDoc;

function RemoteDoc(collectionName, id, shareDoc) {
  this.collectionName = collectionName;
  this.id = id;
  this.shareDoc = shareDoc;
}

RemoteDoc.prototype.path = function(segments) {
  return this.collectionName + '.' + this.id + '.' + segments.join('.');
};

RemoteDoc.prototype.clear = function() {
};

RemoteDoc.prototype.set = function(segments, value, cb) {
  var previous = this._createImplied(segments);
  var op = (previous === void 0) ?
    [new ObjectInsertOp(segments, value)] :
    [new ObjectReplaceOp(segments, previous, value)];
  this.shareDoc.submitOp(op, cb);
  return previous;
};

RemoteDoc.prototype.setNull = function(segments, value, cb) {
  var previous = this.get(segments);
  if (previous != null) {
    cb();
    return previous;
  }
  this._createImplied(segments);
  var op = [new ObjectInsertOp(segments, value)];
  this.shareDoc.submitOp(op, cb);
  return value;
};

RemoteDoc.prototype.increment = function(segments, byNum, cb) {
  var previous = this._createImplied(segments);
  var op = [new IncrementOp(segments, byNum)];
  this.shareDoc.submitOp(op, cb);
  return previous + byNum;
};

RemoteDoc.prototype.stringInsert = function(segments, index, value, cb) {
  var previous = this._createImplied(segments);
  if (previous == null) {
    var op = [new ObjectInsertOp(segments, value)];
    this.shareDoc.submitOp(op, cb);
    return previous;
  }
  var op = [new StringInsertOp(segments, index, value)];
  this.shareDoc.submitOp(op, cb)
  return previous;
};

RemoteDoc.prototype.stringRemove = function(segments, index, howMany, cb) {
  var previous = this._createImplied(segments);
  if (previous == null) return previous;
  var op = [new StringRemoveOp(segments, index, removed)];
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

RemoteDoc.prototype.push = function(segments, values, cb) {
  var shareDoc = this.shareDoc;
  function push(arr, fnCb) {
    var op = eachOp(ListInsertOp, segments, arr.length, values);
    shareDoc.submitOp(op, fnCb);
    return arr.length;
  }
  return this._arrayApply(segments, push, cb);
};

RemoteDoc.prototype.unshift = function(segments, values) {
  var shareDoc = this.shareDoc;
  function unshift(arr, fnCb) {
    var op = eachOp(ListInsertOp, segments, 0, values);
    shareDoc.submitOp(op, fnCb);
    return arr.length;
  }
  return this._arrayApply(segments, unshift, cb);
};

RemoteDoc.prototype.insert = function(segments, index, values) {
  var shareDoc = this.shareDoc;
  function insert(arr, fnCb) {
    var op = eachOp(ListInsertOp, segments, index, values);
    shareDoc.submitOp(op, fnCb);
    return arr.length;
  }
  return this._arrayApply(segments, insert, cb);
};

RemoteDoc.prototype.pop = function(segments) {
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

RemoteDoc.prototype.shift = function(segments) {
  var shareDoc = this.shareDoc;
  function shift(arr, fnCb) {
    var value = arr[0];
    var op = [new ListRemoveOp(segments, 0, value)];
    shareDoc.submitOp(op, fnCb);
    return value;
  }
  return this._arrayApply(segments, shift, cb);
};

RemoteDoc.prototype.remove = function(segments, index, howMany) {
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

RemoteDoc.prototype.move = function(segments, from, to, howMany) {
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
  var node = this.shareDoc.snapshot;
  var i = 0;
  var nextKey;
  while (nextKey = segments[i++]) {
    if (!node) {
      var value = /^\d+$/.test(nextKey) ? [] : {};
      var op = [new ObjectInsertOp(segments.slice(0, i - 1), value)];
      this.shareDoc.submitOp(op);
    }
    node = node[nextKey];
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

function IncrementOp(segments, byNum) {
  this.p = segments;
  this.na = byNum;
}
function StringInsertOp(segments, index, value) {
  this.p = segments.concat(index);
  this.si = value;
}
function StringRemoveOp(segments, index, value) {
  this.p = segments.concat(index);
  this.sd = value;
}
function ListInsertOp(segments, index, value) {
  this.p = segments.concat(index);
  this.li = value;
}
function ListRemoveOp(segments, index, value) {
  this.p = segments.concat(index);
  this.ld = value;
}
function ListReplaceOp(segments, index, before, after) {
  this.p = segments.concat(index);
  this.ld = before;
  this.li = after;
}
function ListMoveOp(segments, from, to) {
  this.p = segments.concat(from);
  this.lm = to;
}
function ObjectInsertOp(segments, value) {
  this.p = segments;
  this.oi = value;
}
function ObjectDeleteOp(segments, value) {
  this.p = segments;
  this.od = value;
}
function ObjectReplaceOp(segments, before, after) {
  this.p = segments;
  this.od = before;
  this.oi = after;
}
