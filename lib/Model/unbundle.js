var Model = require('./Model');

Model.prototype.unbundle = function(data) {
  // Re-create documents for all model data
  for (var collectionName in data.collections) {
    var collection = data.collections[collectionName];
    for (var id in collection) {
      var doc = this.getOrCreateDoc(collectionName, id, collection[id]);
      if (doc.shareDoc) {
        this._loadVersions[collectionName + '.' + id] = doc.shareDoc.version;
      }
    }
  }

  for (var contextId in data.contexts) {
    var context = data.contexts[contextId];
    var contextModel = this.context(contextId);
    // Re-subscribe to document subscriptions
    for (var path in context.subscribedDocs) {
      var segments = path.split('.');
      contextModel.subscribeDoc(segments[0], segments[1]);
      this._subscribedDocs[path] = context.subscribedDocs[path];
    }
    // Init fetchedDocs counts
    for (var path in context.fetchedDocs) {
      this._fetchedDocs[path] = context.fetchedDocs[path];
    }
  }

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
    var filter = this._filters.add(item[1], item[2], item[3], item[4]);
    filter.ref(item[0]);
  }
  // Init and re-subscribe queries as appropriate
  this._initQueries(data.queries, data.contexts);
};
