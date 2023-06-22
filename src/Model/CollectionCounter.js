module.exports = CollectionCounter;

function CollectionCounter() {
  this.reset();
}
CollectionCounter.prototype.reset = function() {
  // A map of CounterMaps
  this.collections = {};
  // The number of id keys in the collections map
  this.size = 0;
};
CollectionCounter.prototype.get = function(collectionName, id) {
  var collection = this.collections[collectionName];
  return (collection && collection.counts[id]) || 0;
};
CollectionCounter.prototype.increment = function(collectionName, id) {
  var collection = this.collections[collectionName];
  if (!collection) {
    collection = this.collections[collectionName] = new CounterMap();
    this.size++;
  }
  return collection.increment(id);
};
CollectionCounter.prototype.decrement = function(collectionName, id) {
  var collection = this.collections[collectionName];
  if (!collection) return 0;
  var count = collection.decrement(id);
  if (collection.size < 1) {
    delete this.collections[collectionName];
    this.size--;
  }
  return count;
};
CollectionCounter.prototype.toJSON = function() {
  // Serialize to the contained count data if any
  if (this.size > 0) {
    var out = {};
    for (var collectionName in this.collections) {
      out[collectionName] = this.collections[collectionName].counts;
    }
    return out;
  }
  return;
};

function CounterMap() {
  this.counts = {};
  this.size = 0;
}
CounterMap.prototype.increment = function(key) {
  var count = this.counts[key] || 0;
  if (count === 0) {
    this.size++;
  }
  return this.counts[key] = count + 1;
};
CounterMap.prototype.decrement = function(key) {
  var count = this.counts[key] || 0;
  if (count > 1) {
    return this.counts[key] = count - 1;
  }
  if (count === 1) {
    delete this.counts[key];
    this.size--;
  }
  return 0;
};
