var Model = require('./Model');
var LocalDoc = require('./LocalDoc');

Model.INITS.push(function(model) {
  model.collections = new CollectionMap;
});

Model.prototype.getCollection = function(collectionName) {
  return this.collections[collectionName];
};
Model.prototype.getDoc = function(collectionName, id) {
  var collection = this.collections[collectionName];
  return collection && collection.docs[id];
};
Model.prototype.get = function(subpath) {
  var segments = this._splitPath(subpath);
  return this._get(segments);
};
Model.prototype._get = function(segments) {
  segments = this._dereference(segments);
  var collectionName = segments[0];
  if (!collectionName) {
    return getEach(this.collections);
  }
  var id = segments[1];
  if (!id) {
    var collection = this.getCollection(collectionName);
    return collection && getEach(collection.docs);
  }
  var doc = this.getDoc(collectionName, id);
  return doc && doc.get(segments.slice(2));
};
Model.prototype.getOrCreateCollection = function(name) {
  var collection = this.collections[name];
  if (collection) return collection;
  var Doc = this._getDocConstructor(name);
  collection = new Collection(this, name, Doc);
  this.collections[name] = collection;
  return collection;
};
Model.prototype._getDocConstructor = function() {
  // Only create local documents. This is overriden in ./connection.js, so that
  // the RemoteDoc behavior can be selectively included
  return LocalDoc;
};

/**
 * Returns an existing document with id in a collection. If the document does
 * not exist, then creates the document with id in a collection and returns the
 * new document.
 * @param {String} collectionName
 * @param {String} id
 * @param {Object} [data] data to create if doc with id does not exist in collection
 */
Model.prototype.getOrCreateDoc = function(collectionName, id, data) {
  var collection = this.getOrCreateCollection(collectionName);
  return collection.docs[id] || collection.add(id, data);
};

/**
 * @param {String} collectionName
 */
Model.prototype.destroy = function(collectionName) {
  // TODO: non-collections
  var collection = this.getCollection(collectionName);
  collection && collection.destroy();
  this.removeAllRefs(collectionName);
  this.stopAll(collectionName);
  this.removeAllFilters(collectionName);
  this.removeAllListeners(null, collectionName);
};

function CollectionMap() {}
function DocMap() {}
function Collection(model, name, Doc) {
  this.model = model;
  this.name = name;
  this.Doc = Doc;
  this.docs = new DocMap();
}

/**
 * Adds a document with `id` and `data` to `this` Collection.
 * @param {String} id
 * @param {Object} data
 * @return {LocalDoc|RemoteDoc} doc
 */
Collection.prototype.add = function(id, data) {
  var doc = new this.Doc(this.name, id, data, this.model);
  this.docs[id] = doc;
  return doc;
};
Collection.prototype.destroy = function() {
  delete this.model.collections[this.name];
};

/**
 * Removes the document with `id` from `this` Collection. If there are no more
 * documents in the Collection after the given document is removed, then this
 * also destroys the Collection.
 * @param {String} id
 */
Collection.prototype.remove = function(id) {
  delete this.docs[id];
  if (noKeys(this.docs)) this.destroy();
};

/**
 * Returns an object that maps doc ids to fully resolved documents.
 * @return {Object}
 */
Collection.prototype.get = function() {
  return getEach(this.docs);
};

function getEach(object) {
  if (!object) return;
  var result = {};
  for (var key in object) {
    result[key] = object[key].get();
  }
  return result;
}

function noKeys(object) {
  for (var key in object) {
    return false;
  }
  return true;
}
