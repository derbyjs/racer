module.exports = LocalDoc;

function LocalDoc(collectionName, id, snapshot) {
  this.collectionName = collectionName;
  this.id = id;
  this.snapshot = snapshot;
}

LocalDoc.prototype.path = function(segments) {
  return this.collectionName + '.' + this.id + '.' + segments.join('.');
};

LocalDoc.prototype.set = function(segments, value, cb) {
  function set(node, key) {
    var previous = node[key];
    node[key] = value;
    return previous;
  }
  return this._apply(segments, set, cb);
};

LocalDoc.prototype.del = function(segments, cb) {
  // Don't do anything if the value is already undefined, since
  // apply creates objects as it traverses, and the del method
  // should not create anything
  var previous = this.get(segments);
  if (previous === void 0) {
    cb();
    return;
  }
  function del(node, key) {
    delete node[key];
    return previous;
  }
  return this._apply(segments, del, cb);
};

LocalDoc.prototype.increment = function(segments, byNumber, cb) {
  var self = this;
  function validate(value) {
    if (typeof value === 'number' || value == null) return;
    return new TypeError(self._errorMessage(
      'increment on non-number', segments, value
    ));
  }
  function increment(node, key) {
    return node[key] = (node[key] || 0) + byNumber;
  }
  return this._validatedApply(segments, validate, increment, cb);
};

LocalDoc.prototype.push = function(segments, value, cb) {
  function push(arr) {
    return arr.push(value);
  }
  return this._arrayApply(segments, push, cb);
};

LocalDoc.prototype.unshift = function(segments, value, cb) {
  function unshift(arr) {
    return arr.unshift(value);
  }
  return this._arrayApply(segments, unshift, cb);
};

LocalDoc.prototype.insert = function(segments, index, values, cb) {
  function insert(arr) {
    arr.splice.apply(arr, [index, 0].concat(values));
    return;
  }
  return this._arrayApply(segments, insert, cb);
};

LocalDoc.prototype.pop = function(segments, cb) {
  function pop(arr) {
    return arr.pop();
  }
  return this._arrayApply(segments, pop, cb);
};

LocalDoc.prototype.shift = function(segments, cb) {
  function shift(arr) {
    return arr.shift();
  }
  return this._arrayApply(segments, shift, cb);
};

LocalDoc.prototype.remove = function(segments, index, howMany, cb) {
  function remove(arr) {
    return arr.splice(index, howMany);
  }
  return this._arrayApply(segments, remove, cb);
};

LocalDoc.prototype.move = function(segments, from, to, howMany, cb) {
  function move(arr) {
    var len = arr.length;
    // Cast to numbers
    from = +from;
    to = +to;
    // Make sure indices are positive
    if (from < 0) from += len;
    if (to < 0) to += len;
    // Remove from old location
    var values = arr.splice(from, howMany);
    // Insert in new location
    arr.splice.apply(arr, [to, 0].concat(values));
    return values;
  }
  return this._arrayApply(segments, move, cb);
};

LocalDoc.prototype.stringInsert = function(segments, index, value, cb) {
  var self = this;
  function validate(value) {
    if (typeof value === 'string' || value == null) return;
    return new TypeError(self._errorMessage(
      'stringInsert on non-string', segments, value
    ));
  }
  function stringInsert(node, key) {
    var previous = node[key];
    if (previous == null) {
      node[key] = value;
      return;
    }
    node[key] = previous.slice(0, index) + value + previous.slice(index);
    return;
  }
  return this._validatedApply(segments, validate, stringInsert, cb);
};

LocalDoc.prototype.stringRemove = function(segments, index, howMany, cb) {
  var self = this;
  function validate(value) {
    if (typeof value === 'string' || value == null) return;
    return new TypeError(self._errorMessage(
      'stringRemove on non-string', segments, value
    ));
  }
  function stringRemove(node, key) {
    var previous = node[key];
    if (previous == null) return;
    if (index < 0) index += previous.length;
    node[key] = previous.slice(0, index) + previous.slice(index + howMany);
    return;
  }
  return this._validatedApply(segments, validate, stringRemove, cb);
};

LocalDoc.prototype.get = function(segments) {
  if (!segments) return this.snapshot;
  var node = this.snapshot;
  var i = 0;
  var key;
  while (key = segments[i++]) {
    if (node == null) return;
    node = node[key];
  }
  return node;
};

LocalDoc.prototype._createImplied = function(segments, fn) {
  var node = this;
  var key = 'snapshot';
  var i = 0;
  var nextKey;
  while (nextKey = segments[i++]) {
    // Get or create implied object or array
    node = node[key] || (node[key] = /^\d+$/.test(nextKey) ? [] : {});
    key = nextKey;
  }
  return fn(node, key);
};

LocalDoc.prototype._apply = function(segments, fn, cb) {
  var out = this._createImplied(segments, fn);
  cb();
  return out;
};

LocalDoc.prototype._validatedApply = function(segments, validate, fn, cb) {
  this._createImplied(segments, function(node, key) {
    var err = validate(node[key]);
    if (err) return cb(err);
    var out = fn(node, key);
    cb();
    return out;
  });
};

LocalDoc.prototype._arrayApply = function(segments, fn, cb) {
  // Lookup a pointer to the property or nested property &
  // return the current value or create a new array
  var arr = this._createImplied(segments, nodeCreateArray);

  if (!Array.isArray(arr)) {
    var message = this._errorMessage(fn.name + ' on non-array', segments, arr);
    var err = new TypeError(message);
    return cb(err);
  }
  var out = fn(arr);
  cb();
  return out;
};
function nodeCreateArray(node, key) {
  return node[key] || (node[key] = []);
}

LocalDoc.prototype._errorMessage = function(description, segments, value) {
  return description + ' at ' + this.path(segments) + ': ' +
    JSON.stringify(value, null, 2);
};
