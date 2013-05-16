var Model = require('./index');

Model.BUNDLE_TIMEOUT = 10 * 1000;

Model.INITS.push(function(model, options) {
  model.bundleTimeout = options.bundleTimeout || Model.BUNDLE_TIMEOUT;
});

Model.prototype.bundle = function(cb) {
  var model = this;
  var timeout = setTimeout(function() {
    var message = 'Model bundle took longer than ' + model.bundleTimeout + 'ms';
    var err = new Error(message);
    cb(err);
    // Keep the callback from being called more than once
    cb = function() {};
  }, this.bundleTimeout);

  whenNothingPending(model, function finishBundle() {
    clearTimeout(timeout);
    var bundle = {
      collections: serializeCollections(model)
    , queries: model._queries
    , fetchedDocs: model._fetchedDocs
    , subscribedDocs: model._subscribedDocs
    , refs: model._refs
    , refLists: model._refLists
    };
    model.emit('bundle', bundle);
    model._commit = errorOnCommit;
    cb(null, bundle);
  });
};

function whenNothingPending(model, cb) {
  // Call back when no Share documents have pending operations
  for (var collectionName in model.collections) {
    var collection = model.collections[collectionName];
    for (var id in collection.docs) {
      var doc = collection.docs[id];
      // If a document is found with a pending operation, wait for it to emit
      // that nothing is pending anymore, and then recheck all documents again.
      // We have to recheck all documents, just in case another mutation has
      // been made in the meantime as a result of an event callback
      if (doc.shareDoc && doc.shareDoc.hasPending()) {
        doc.shareDoc.once('nothing pending', retryNothingPending);
        return;
      }
    }
  }
  cb();
  function retryNothingPending() {
    whenNothingPending(model, cb);
  }
}

function serializeCollections(model) {
  var out = {};
  for (var collectionName in model.collections) {
    var collection = model.collections[collectionName];
    out[collectionName] = {};
    for (var id in collection.docs) {
      var doc = collection.docs[id];
      var shareDoc = doc.shareDoc;
      out[collectionName][id] = (shareDoc) ?
        {
          v: shareDoc.version
        , snapshot: shareDoc.snapshot
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
