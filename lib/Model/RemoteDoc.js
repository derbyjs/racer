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
  var previous = this.get(segments);
  if (previous === void 0) {
    this._createImplied(segments);
    var op = [new ObjectInsertOp(segments, value)];
  } else {
    var op = [new ObjectReplaceOp(segments, previous, value)];
  }
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
  this._createImplied(segments);
  var op = [new IncrementOp(segments, byNum)];
  this.shareDoc.submitOp(op, cb);
  return this.get(segments);
};

RemoteDoc.prototype.del = function(segments, cb) {
  // Don't do anything if the value is already undefined, since
  // lookupSet creates objects as it traverses, and the del
  // method should not create anything
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
  this._createImplied(segments, true);
  var arr = this.get(segments);
  if (!Array.isArray(arr)) {
    var err = new TypeError(this._errorMessage(
      'push on non-array', segments, arr
    ));
    return cb(err);
  }
  var op = [new ListInsertOp(segments, arr.length, byNum)];
  this.shareDoc.submitOp(op, cb);
  return arr.length;
};

RemoteDoc.prototype.unshift = function(segments, values) {
};

RemoteDoc.prototype.insert = function(segments, index, values) {
};

RemoteDoc.prototype.pop = function(segments) {
};

RemoteDoc.prototype.shift = function(segments) {
};

RemoteDoc.prototype.remove = function(segments, index, howMany) {
};

RemoteDoc.prototype.move = function(segments, from, to, howMany) {
};

RemoteDoc.prototype.stringInsert = function(segments, index, value) {
};

RemoteDoc.prototype.stringRemove = function(segments, index, howMany) {
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

RemoteDoc.prototype._createImplied = function(segments, isArray) {
  var node = this.shareDoc;
  var key = 'snapshot';
  var i = 0;
  var nextKey;
  while (nextKey = segments[i++]) {
    if (node) {
      node = node[key];
    } else {
      var value = /^\d+$/.test(nextKey) ? [] : {};
      var op = [new ObjectInsertOp(segments.slice(0, i), value)];
      this.shareDoc.submitOp(op);
    }
    key = nextKey;
  }
  if (isArray) {
    var op = [new ObjectInsertOp(segments, [])];
    this.shareDoc.submitOp(op);
  }
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
