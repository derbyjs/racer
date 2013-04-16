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
  var path = this.path(subpath);
  var segments = path.split('.');
  if (!segments) {
    return getEach(this.collections);
  }
  var collectionName = segments[0];
  if (!collectionName) {
    return getEach(this.collections);
  }
  var id = segments[1];
  if (!id) {
    var collection = this.getCollection(collectionName);
    return getEach(collection.docs);
  }
  var doc = this.getDoc(collectionName, id);
  return doc.get(segments.slice(2));
};
Model.prototype.getOrCreateCollection = function(name) {
  var collection = this.collections[name];
  if (collection) return collection;
  var isLocal = name.charAt(0) === '_';
  return this.collections[name] = new Collection(name, isLocal);
};
Model.prototype.getOrCreateDoc = function(collectionName, id, data) {
  var collection = this.getOrCreateCollection(collectionName);
  return collection.docs[id] || collection.add(id, data);
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
