import { FastMap } from './FastMap';
import { Collection } from './collections';

export class CollectionMap{
  collections: Record<string, FastMap<Collection>>;

  constructor() {
    // A map of collection names to FastMaps
    this.collections = {};
  }

  getCollection(collectionName) {
    var collection = this.collections[collectionName];
    return (collection && collection.values);
  };

  get(collectionName, id) {
    var collection = this.collections[collectionName];
    return (collection && collection.values[id]);
  };

  set(collectionName, id, value) {
    var collection = this.collections[collectionName];
    if (!collection) {
      collection = this.collections[collectionName] = new FastMap();
    }
    collection.set(id, value);
  };

  del(collectionName, id) {
    var collection = this.collections[collectionName];
    if (collection) {
      collection.del(id);
      if (collection.size > 0) return;
      delete this.collections[collectionName];
    }
  };
}
