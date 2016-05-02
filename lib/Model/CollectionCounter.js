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
  var count = (collection[id] || 0) + 1;
  collection[id] = count;
  return count;
};
CollectionCounter.prototype.decrement = function(collectionName, id) {
  var collection = this.collections[collectionName];
  var count = collection && collection[id];
  if (count == null) return;
  if (count > 1) {
    count--;
    collection[id] = count;
    return count;
  }
  delete collection[id];
  // Check if the collection still has any keys
  // eslint-disable-next-line no-unused-vars
  for (var key in collection) return 0;
  delete this.collections[collection];
  return 0;
};
CollectionCounter.prototype.toJSON = function() {
  // Check to see if we have any keys
  // eslint-disable-next-line no-unused-vars
  for (var key in this.collections) {
    return this.collections;
  }
  return;
};
