var Model = require('./Model');

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

  this.whenNothingPending(function finishBundle() {
    clearTimeout(timeout);
    var bundle = {
      queries: model._queries
    , contexts: model._contexts
    , refs: model._refs
    , refLists: model._refLists
    , fns: model._fns
      // Get the filters before removing their computed values below
    , filters: model._filters.toJSON()
    , nodeEnv: process.env.NODE_ENV
    };
    stripComputed(model);
    bundle.collections = serializeCollections(model);
    model.emit('bundle', bundle);
    model._commit = errorOnCommit;
    cb(null, bundle);
  });
};

Model.prototype.hasPending = function() {
  return !!this._firstPendingDoc();
};

Model.prototype.whenNothingPending = function(cb) {
  var doc = this._firstPendingDoc();
  if (doc) {
    // If a document is found with a pending operation, wait for it to emit
    // that nothing is pending anymore, and then recheck all documents again.
    // We have to recheck all documents, just in case another mutation has
    // been made in the meantime as a result of an event callback
    var model = this;
    doc.shareDoc.once('nothing pending', function retryNothingPending() {
      model.whenNothingPending(cb);
    });
    return;
  }
  // Call back when no Share documents have pending operations
  process.nextTick(cb);
};

Model.prototype._firstPendingDoc = function() {
  // Loop through all of this model's documents, and return the first document
  // encountered with a pending Share operation
  for (var collectionName in model.collections) {
    var collection = model.collections[collectionName];
    for (var id in collection.docs) {
      var doc = collection.docs[id];
      if (doc.shareDoc && doc.shareDoc.hasPending()) {
        return doc;
      }
    }
  }
};

function stripComputed(model) {
  var silentModel = model.silent();
  var refListsMap = model._refLists.fromMap;
  var fnsMap = model._fns.fromMap;
  for (var from in refListsMap) {
    silentModel._del(refListsMap[from].fromSegments);
  }
  for (var from in fnsMap) {
    silentModel._del(fnsMap[from].fromSegments);
  }
  silentModel.removeAllFilters();
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
