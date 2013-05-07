var racer = require('../racer');
var util = require('../util');
var Model = require('./index');

Model.prototype.bundle = function(cb) {
  var model = this;
  var group = util.asyncGroup(finishBundle);
  this.emit('bundle', this, group);
  group()();

  var delay = racer.get('bundleTimeout');
  var timeout = setTimeout(function() {
    var err = new Error('Model bundling took longer than ' + delay + ' ms');
    group()(err);
  }, delay);

  function finishBundle(err) {
    clearTimeout(timeout);
    if (err) return cb(err);
    var bundle = {
      collections: serializeCollections(model)
    , queries: model._queries
    , fetchedDocs: model._fetchedDocs
    , subscribedDocs: model._subscribedDocs
    , refs: model._refs
    , refLists: model._refLists
    };
    model._commit = errorOnCommit;
    cb(null, bundle);
  }
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

function errorOnCommit() {
  this.emit('error', new Error('Model mutation performed after bundling'));
}
