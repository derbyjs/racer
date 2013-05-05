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
      out[collectionName][id] = (doc.shareDoc) ?
        {v: doc.shareDoc.version, snapshot: doc.shareDoc.snapshot} :
        doc.snapshot;
    }
  }
  return out;
}

function finishBundle(model, cb) {
  var bundle = {
    collections: serializeCollections(model)
  , queries: model._queries
  , fetchedDocs: model._fetchedDocs
  , subscribedDocs: model._subscribedDocs
  , refs: model._refs
  , refLists: model._refLists
  };
  cb(null, JSON.stringify(bundle));
  model._commit = errorOnCommit;
}

function errorOnCommit() {
  this.emit('error', new Error('Model mutation performed after bundling'));
}
