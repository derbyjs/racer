module.exports = CollectionMap;

function CollectionMap() {
  // A map of collection names to FastMaps
  this.collections = {};
}
CollectionMap.prototype.getCollection = function(collectionName) {
  var collection = this.collections[collectionName];
  return (collection && collection.values);
};
CollectionMap.prototype.get = function(collectionName, id) {
  var collection = this.collections[collectionName];
  return (collection && collection.values[id]);
};
CollectionMap.prototype.set = function(collectionName, id, value) {
  var collection = this.collections[collectionName];
  if (!collection) {
    collection = this.collections[collectionName] = new FastMap();
  }
  collection.set(id, value);
};
CollectionMap.prototype.del = function(collectionName, id) {
  var collection = this.collections[collectionName];
  if (collection) {
    collection.del(id);
    if (collection.size > 0) return;
    delete this.collections[collectionName];
  }
};

function FastMap() {
  this.values = {};
  this.size = 0;
}
FastMap.prototype.set = function(key, value) {
  if (!(key in this.values)) {
    this.size++;
  }
  this.values[key] = value;
};
FastMap.prototype.del = function(key) {
  if (key in this.values) {
    this.size--;
  }
  delete this.values[key];
};
