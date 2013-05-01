var racer = require('../racer');
var util = require('../util');
var Model = require('./index');

racer.on('Model:init', function(model) {
  model._bundlePromises = [];
  model._onLoad = [];
});

Model.prototype.bundle = function(cb) {
  this.emit('bundle', this);
  if (!this._bundlePromises.length) return finishBundle(this, cb);

  var bundlePromise = util.Promise.parallel(this._bundlePromises);

  var delay = racer.get('bundleTimeout');
  var timeout = setTimeout(function() {
    var err = new Error('Model bundling took longer than ' + delay + ' ms');
    bundlePromise.resolve(err);
  }, delay);

  var model = this;
  bundlePromise.on(function(err) {
    clearTimeout(timeout);
    if (err) return cb(err);
    finishBundle(model, cb);
  });
};

function serializeCollections(model) {
  var out = {};

  for (var collectionName in model.collections) {
    out[collectionName] = {};
    var collection = model.collections[collectionName];
    for (var id in collection.docs) {
      var doc = collection.docs[id];
      var docOut = out[collectionName][id] = {};
      if (doc.shareDoc) {
        docOut.v = doc.shareDoc.version;
        docOut.snapshot = doc.shareDoc.snapshot;
      } else {
        docOut.snapshot = doc.snapshot;
      }
    }
  }

  return out;
}

function finishBundle(model, cb) {
  var bundle = {
    snapshot: serializeCollections(model)
  , subscribedQueries: []
  , subscribedDocs: []
  , refs: model._refs
  , refLists: model._refLists
  };
  for (var hash in model._queries) {
    var query = model._queries[hash];
    if (query.isSubscribed) bundle.subscribedQueries.push(query.serialize());
  }
  for (var path in model._subscribedDocs) {
    bundle.subscribedDocs.push(path);
  }
  cb(null, JSON.stringify(bundle));
  model._commit = errorOnCommit;
}

function errorOnCommit() {
  throw new Error('Model mutation performed after bundling for clientId: ' + this._clientId)
}
