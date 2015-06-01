var Model = require('./Model');

Model.prototype.unbundle = function(data) {
  if (this.shareConnection) this.shareConnection.bsStart();

  // Re-create and subscribe queries; re-create documents associated with queries
  this._initQueries(data.queries);

  // Re-create other documents
  for (var collectionName in data.collections) {
    var collection = data.collections[collectionName];
    for (var id in collection) {
      this.getOrCreateDoc(collectionName, id, collection[id]);
    }
  }

  for (var contextId in data.contexts) {
    var contextData = data.contexts[contextId];
    var contextModel = this.context(contextId);
    // Re-init fetchedDocs counts
    for (var collectionName in contextData.fetchedDocs) {
      var collection = contextData.fetchedDocs[collectionName];
      for (var id in collection) {
        var count = collection[id];
        while (count--) {
          contextModel._context.fetchDoc(collectionName, id);
          this._fetchedDocs.increment(collectionName, id);
        }
      }
    }
    // Subscribe to document subscriptions
    for (var collectionName in contextData.subscribedDocs) {
      var collection = contextData.subscribedDocs[collectionName];
      for (var id in collection) {
        var count = collection[id];
        while (count--) {
          contextModel.subscribeDoc(collectionName, id);
        }
      }
    }
    // Re-init createdDocs counts
    for (var collectionName in contextData.createdDocs) {
      var collection = contextData.createdDocs[collectionName];
      for (var id in collection) {
        // Count value doesn't matter for tracking creates
        contextModel._context.createDoc(collectionName, id);
      }
    }
  }

  if (this.shareConnection) this.shareConnection.bsEnd();

  // Re-create refs
  for (var i = 0; i < data.refs.length; i++) {
    var item = data.refs[i];
    this.ref(item[0], item[1]);
  }
  // Re-create refLists
  for (var i = 0; i < data.refLists.length; i++) {
    var item = data.refLists[i];
    this.refList(item[0], item[1], item[2], item[3]);
  }
  // Re-create fns
  for (var i = 0; i < data.fns.length; i++) {
    var item = data.fns[i];
    this.start.apply(this, item);
  }
  // Re-create filters
  for (var i = 0; i < data.filters.length; i++) {
    var item = data.filters[i];
    var filter = this._filters.add(item[1], item[2], item[3], item[4], item[5]);
    filter.ref(item[0]);
  }
};
