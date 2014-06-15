var Model = require('./Model');

Model.BUNDLE_TIMEOUT = 10 * 1000;

Model.INITS.push(function(model, options) {
  model.root.bundleTimeout = options.bundleTimeout || Model.BUNDLE_TIMEOUT;
});

Model.prototype.bundle = function(cb) {
  var root = this.root;
  var timeout = setTimeout(function() {
    var message = 'Model bundle took longer than ' + root.bundleTimeout + 'ms';
    var err = new Error(message);
    cb(err);
    // Keep the callback from being called more than once
    cb = function() {};
  }, root.bundleTimeout);

  root.whenNothingPending(function finishBundle() {
    clearTimeout(timeout);
    stripIds(root);
    var bundle = {
      queries: root._queries.toJSON()
    , contexts: root._contexts
    , refs: root._refs.toJSON()
    , refLists: root._refLists.toJSON()
    , fns: root._fns.toJSON()
    , filters: root._filters.toJSON()
    , nodeEnv: process.env.NODE_ENV
    };
    stripComputed(root);
    bundle.collections = serializeCollections(root);
    root.emit('bundle', bundle);
    root._commit = errorOnCommit;
    cb(null, bundle);
  });
};

function stripIds(root) {
  // Strip ids from remote documents, which get added automatically. Don't do
  // this for local documents, since they are often not traditional object
  // documents with ids and it doesn't make sense to add ids to them always
  for (var collectionName in root.data) {
    if (root._isLocal(collectionName)) continue;
    var collectionData = root.data[collectionName];
    for (var id in collectionData) {
      var docData = collectionData[id];
      if (docData) delete docData.id;
    }
  }
}

function stripComputed(root) {
  var silentModel = root.silent();
  var refListsMap = root._refLists.fromMap;
  var fnsMap = root._fns.fromMap;
  for (var from in refListsMap) {
    silentModel._del(refListsMap[from].fromSegments);
  }
  for (var from in fnsMap) {
    silentModel._del(fnsMap[from].fromSegments);
  }
  silentModel.removeAllFilters();
  silentModel.destroy('$queries');
}

function serializeCollections(root) {
  var out = {};
  for (var collectionName in root.collections) {
    var collection = root.collections[collectionName];
    out[collectionName] = {};
    for (var id in collection.docs) {
      var doc = collection.docs[id];
      var shareDoc = doc.shareDoc;
      out[collectionName][id] = (shareDoc) ?
        {
          v: shareDoc.version
        , data: shareDoc.snapshot
        , type: shareDoc.type && shareDoc.type.name
        } :
        doc.snapshot;
    }
  }
  return out;
}

function errorOnCommit() {
  this.emit('error', new Error('Model mutation performed after bundling'));
}
