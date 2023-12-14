/**
 * Contexts are useful for keeping track of the origin of subscribes.
 */

import { Model } from './Model';
import { CollectionCounter } from './CollectionCounter';

declare module './Model' {
  interface Model {
    _contexts: Contexts;
    context(id: string): Model;
    setContext(id: string): void;
    getOrCreateContext(id: string): Context;
    unload(id: string): void;
    unloadAll(): void;
  }
}

Model.INITS.push(function(model) {
  model.root._contexts = new Contexts();
  model.root.setContext('root');
});

Model.prototype.context = function(id) {
  var model = this._child();
  model.setContext(id);
  return model;
};

Model.prototype.setContext = function(id) {
  this._context = this.getOrCreateContext(id);
};

Model.prototype.getOrCreateContext = function(id) {
  var context = this.root._contexts[id] ||
    (this.root._contexts[id] = new Context(this, id));
  return context;
};

Model.prototype.unload = function(id) {
  var context = (id) ? this.root._contexts[id] : this._context;
  context && context.unload();
};

Model.prototype.unloadAll = function() {
  var contexts = this.root._contexts;
  for (var key in contexts) {
    if (contexts.hasOwnProperty(key)) {
      contexts[key].unload();
    }
  }
};

export class Contexts {
  toJSON = function() {
    var out = {};
    var contexts = this;
    for (var key in contexts) {
      if (contexts[key] instanceof Context) {
        out[key] = contexts[key].toJSON();
      }
    }
    return out;
  };
}

class FetchedQueries { }
class SubscribedQueries { }

export class Context {
  model: Model;
  id: string;
  fetchedDocs: CollectionCounter;
  subscribedDocs: CollectionCounter;
  createdDocs: CollectionCounter;
  fetchedQueries: FetchedQueries;
  subscribedQueries: SubscribedQueries;

  constructor(model: Model, id: string) {
    this.model = model;
    this.id = id;
    this.fetchedDocs = new CollectionCounter();
    this.subscribedDocs = new CollectionCounter();
    this.createdDocs = new CollectionCounter();
    this.fetchedQueries = new FetchedQueries();
    this.subscribedQueries = new SubscribedQueries();
  }

  toJSON() {
    var fetchedDocs = this.fetchedDocs.toJSON();
    var subscribedDocs = this.subscribedDocs.toJSON();
    var createdDocs = this.createdDocs.toJSON();
    if (!fetchedDocs && !subscribedDocs && !createdDocs) return;
    return {
      fetchedDocs: fetchedDocs,
      subscribedDocs: subscribedDocs,
      createdDocs: createdDocs
    };
  };

  fetchDoc(collectionName, id) {
    this.fetchedDocs.increment(collectionName, id);
  };
  subscribeDoc(collectionName, id) {
    this.subscribedDocs.increment(collectionName, id);
  };
  unfetchDoc(collectionName, id) {
    this.fetchedDocs.decrement(collectionName, id);
  };
  unsubscribeDoc(collectionName, id) {
    this.subscribedDocs.decrement(collectionName, id);
  };
  createDoc(collectionName, id) {
    this.createdDocs.increment(collectionName, id);
  };
  fetchQuery(query) {
    mapIncrement(this.fetchedQueries, query.hash);
  };
  subscribeQuery(query) {
    mapIncrement(this.subscribedQueries, query.hash);
  };
  unfetchQuery(query) {
    mapDecrement(this.fetchedQueries, query.hash);
  };
  unsubscribeQuery(query) {
    mapDecrement(this.subscribedQueries, query.hash);
  };

  unload() {
    var model = this.model;
    for (var hash in this.fetchedQueries) {
      var query = model.root._queries.map[hash];
      if (!query) continue;
      var count = this.fetchedQueries[hash];
      while (count--) query.unfetch();
    }
    for (var hash in this.subscribedQueries) {
      var query = model.root._queries.map[hash];
      if (!query) continue;
      var count = this.subscribedQueries[hash];
      while (count--) query.unsubscribe();
    }
    for (var collectionName in this.fetchedDocs.collections) {
      var collection = this.fetchedDocs.collections[collectionName];
      for (var id in collection.counts) {
        var count = collection.counts[id];
        while (count--) model.unfetchDoc(collectionName, id);
      }
    }
    for (var collectionName in this.subscribedDocs.collections) {
      var collection = this.subscribedDocs.collections[collectionName];
      for (var id in collection.counts) {
        var count = collection.counts[id];
        while (count--) model.unsubscribeDoc(collectionName, id);
      }
    }
    for (var collectionName in this.createdDocs.collections) {
      var collection = this.createdDocs.collections[collectionName];
      for (var id in collection.counts) {
        model._maybeUnloadDoc(collectionName, id);
      }
    }
    this.createdDocs.reset();
  };
}
function mapIncrement(map, key) {
  map[key] = (map[key] || 0) + 1;
}
function mapDecrement(map, key) {
  map[key] && map[key]--;
  if (!map[key]) delete map[key];
}
