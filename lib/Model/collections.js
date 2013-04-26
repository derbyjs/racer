var racer = require('../racer');
var Model = require('./index');
var LocalDoc = require('./LocalDoc');
var RemoteDoc = require('./RemoteDoc');

racer.on('Model:init', function(model) {
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
  var segments = this._resolvePath(subpath);
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
  var isLocal = name.charAt(0) === '_';
  var Doc = (isLocal) ? LocalDoc : RemoteDoc;
  return this.collections[name] = new Collection(this, name, Doc);
};
Model.prototype.getOrCreateDoc = function(collectionName, id, data) {
  var collection = this.getOrCreateCollection(collectionName);
  return collection.docs[id] || collection.add(id, data);
};

function CollectionMap() {}
function DocMap() {}
function Collection(model, name, Doc) {
  this.model = model;
  this.name = name;
  this.Doc = Doc;
  this.docs = new DocMap();
}
Collection.prototype.add = function(id, data) {
  var doc = new this.Doc(this.name, id, data, this.model);
  return this.docs[id] = doc;
};
Collection.prototype.remove = function(id) {
  this.docs[id].clear();
  delete this.docs[id];
};
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
