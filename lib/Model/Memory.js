module.exports = Memory;

function Memory() {
  this.collections = new CollectionMap();
}
Memory.prototype.getCollection = function(collectionName) {
  return this.collections[collectionName];
};
Memory.prototype.getDoc = function(collectionName, id) {
  var collection = this.collections[collectionName];
  return collection && collection.docs[id];
};
Memory.prototype.getOrCreateCollection = function(name) {
  var collection = this.collections[name];
  if (collection) return collection;
  var isLocal = name.charAt(0) === '_';
  return this.collections[name] = new Collection(name, isLocal);
};
Memory.prototype.getOrCreateDoc = function(collectionName, id) {
  var collection = this.getOrCreateCollection(collectionName);
  return collection.docs[id] || collection.add(id);
};

function CollectionMap() {}
function DocMap() {}
function Collection(name, isLocal) {
  this.name = name;
  this.isLocal = isLocal;
  this.Doc = (isLocal) ? LocalDoc : RemoteDoc;
  this.docs = new DocMap();
}
Collection.prototype.add = function(id, data) {
  return this.docs[id] = new this.Doc(this.name, id, data);
};
Collection.prototype.remove = function(id) {
  this.docs[id].clear();
  delete this.docs[id];
};

function RemoteDoc(collectionName, id, data) {
  // Delegate to ShareJS Doc
}

function LocalDoc(collectionName, id, data) {
  this.collectionName = collectionName;
  this.id = id;
  this.data = data;
}

LocalDoc.prototype.clear = function() {
  this.data = null;
};

LocalDoc.prototype.set = function(segments, value) {
  // Lookup a pointer to the property or nested property,
  // set the new value, and return the previous value
  function nodeSet(node, key) {
    var previous = node[key];
    node[key] = value;
    return previous;
  }
  return this._lookupSet(segments, nodeSet);
};

LocalDoc.prototype.del = function(segments) {
  // Don't do anything if the value is already undefined, since
  // lookupSet creates objects as it traverses, and the del
  // method should not create anything
  var previous = this.get(segments);
  if (previous === void 0) return;
  // Lookup a pointer to the property or nested property,
  // delete the property, and return the previous value
  this._lookupSet(segments, nodeDel);
  return previous;
};
function nodeDel(node, key) {
  delete node[key];
}

LocalDoc.prototype.push = function(segments, values) {
  var arr = this._lookupArray(segments);
  return arr.push.apply(arr, values);
};

LocalDoc.prototype.unshift = function(segments, values) {
  var arr = this._lookupArray(segments);
  return arr.unshift.apply(arr, values);
};

LocalDoc.prototype.insert = function(segments, index, values) {
  var arr = this._lookupArray(segments);
  arr.splice.apply(arr, [index, 0].concat(values));
  return arr.length;
};

LocalDoc.prototype.pop = function(segments) {
  var arr = this._lookupArray(segments);
  return arr.pop();
};

LocalDoc.prototype.shift = function(segments) {
  var arr = this._lookupArray(segments);
  return arr.shift();
};

LocalDoc.prototype.remove = function(segments, index, howMany) {
  var arr = this._lookupArray(segments);
  return arr.splice(index, howMany);
};

LocalDoc.prototype.move = function(segments, from, to, howMany) {
  var arr = this._lookupArray(segments);
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
};

LocalDoc.prototype.get = function(segments) {
  if (!segments) return this.data;
  var node = this.data;
  var i = 0;
  var key;
  while (key = segments[i++]) {
    if (node == null) return;
    node = node[key];
  }
  return node;
};

LocalDoc.prototype._lookupSet = function(segments, fn) {
  var node = this;
  var key = 'data';
  var i = 0;
  var nextKey;
  while (nextKey = segments[i++]) {
    // Get or create implied object or array
    node = node[key] || (node[key] = /^\d+$/.test(nextKey) ? [] : {});
    key = nextKey;
  }
  return fn(node, key);
};

LocalDoc.prototype._lookupArray = function(segments) {
  // Lookup a pointer to the property or nested property &
  // return the current value or create a new array
  var arr = this._lookupSet(segments, nodeCreateArray);

  if (!Array.isArray(arr)) {
    throw new TypeError('Array method called on non-array at ' +
      this.collectionName + '.' + this.id + '.' +
      segments.join('.') + ': ' + JSON.stringify(arr, null, 2)
    );
  }
  return arr;
};
function nodeCreateArray(node, key) {
  return node[key] || (node[key] = []);
}
