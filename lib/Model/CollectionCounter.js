module.exports = CollectionCounter;

function CollectionCounter() {
  this.reset();
}
CollectionCounter.prototype.reset = function() {
  this.collections = {};
};
CollectionCounter.prototype.get = function(collectionName, id) {
  var collection = this.collections[collectionName];
  return collection && collection[id];
};
CollectionCounter.prototype.increment = function(collectionName, id) {
  var collection = this.collections[collectionName] ||
    (this.collections[collectionName] = {});
  return collection[id] = (collection[id] || 0) + 1;
};
CollectionCounter.prototype.decrement = function(collectionName, id) {
  var collection = this.collections[collectionName];
  var count = collection && collection[id];
  if (count == null) return;
  if (count > 1) {
    return collection[id] = count - 1;
  }
  delete collection[id];
  // Check if the collection still has any keys
  for (var key in collection) return 0;
  delete this.collections[collection];
  return 0;
};
CollectionCounter.prototype.toJSON = function() {
  // Check to see if we have any keys
  for (var key in this.collections) {
    return this.collections;
  }
  return;
};
