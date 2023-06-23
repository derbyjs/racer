var Model = require('./Model');
var defaultType = require('sharedb/lib/client').types.defaultType;
var promisify = require('../util').promisify;

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
    var bundle = {
      queries: root._queries.toJSON(),
      contexts: root._contexts.toJSON(),
      refs: root._refs.toJSON(),
      refLists: root._refLists.toJSON(),
      fns: root._fns.toJSON(),
      filters: root._filters.toJSON(),
      nodeEnv: process.env.NODE_ENV
    };
    stripComputed(root);
    bundle.collections = serializeCollections(root);
    root.emit('bundle', bundle);
    root._commit = errorOnCommit;
    cb(null, bundle);
  });
};
Model.prototype.bundlePromised = promisify(Model.prototype.bundle);

function stripComputed(root) {
  var silentModel = root.silent();
  root._refLists.fromMap.forEach(function(refList) {
    silentModel._del(refList.fromSegments);
  });
  root._refs.fromMap.forEach(function(ref) {
    silentModel._delNoDereference(ref.fromSegments);
  });
  root._fns.fromMap.forEach(function(fn) {
    silentModel._del(fn.fromSegments);
  });
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
      var snapshot;
      if (shareDoc) {
        if (shareDoc.type == null && shareDoc.version == null) {
          snapshot = undefined;
        } else {
          snapshot = {
            v: shareDoc.version,
            data: shareDoc.data
          };
          if (shareDoc.type !== defaultType) {
            snapshot.type = doc.shareDoc.type && doc.shareDoc.type.name;
          }
        }
      } else {
        snapshot = doc.data;
      }
      out[collectionName][id] = snapshot;
    }
  }
  return out;
}

function errorOnCommit() {
  this.emit('error', new Error('Model mutation performed after bundling'));
}
