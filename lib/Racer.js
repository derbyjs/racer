var EventEmitter = require('events').EventEmitter;
var Model = require('./Model');
var util = require('./util');

module.exports = Racer;

function Racer() {
  EventEmitter.call(this);
}

util.mergeInto(Racer.prototype, EventEmitter.prototype);

// Make classes accessible for use by plugins and tests
Racer.prototype.Model = Model;
Racer.prototype.util = util;

// Support plugins on racer instances
Racer.prototype.use = util.use;

Racer.prototype.createModel = function(data) {
  var model = new Model();
  model._createConnection(data);

  this.emit('model', model);

  // Re-create documents for all model data
  for (var collectionName in data.collections) {
    var collection = data.collections[collectionName];
    for (var id in collection) {
      var doc = model.getOrCreateDoc(collectionName, id, collection[id]);
      if (doc.shareDoc) {
        model._loadVersions[collectionName + '.' + id] = doc.shareDoc.version;
      }
    }
  }

  for (var contextId in data.contexts) {
    var context = data.contexts[contextId];
    var contextModel = model.context(contextId);
    // Re-subscribe to document subscriptions
    for (var path in context.subscribedDocs) {
      var segments = path.split('.');
      contextModel.subscribeDoc(segments[0], segments[1]);
      model._subscribedDocs[path] = context.subscribedDocs[path];
    }
    // Init fetchedDocs counts
    for (var path in context.fetchedDocs) {
      model._fetchedDocs[path] = context.fetchedDocs[path];
    }
  }

  // Re-create refs
  for (var i = 0; i < data.refs.length; i++) {
    var item = data.refs[i];
    model.ref(item[0], item[1]);
  }
  // Re-create refLists
  for (var i = 0; i < data.refLists.length; i++) {
    var item = data.refLists[i];
    model.refList(item[0], item[1], item[2], item[3]);
  }
  // Re-create fns
  for (var i = 0; i < data.fns.length; i++) {
    var item = data.fns[i];
    model.start.apply(model, item);
  }
  // Re-create filters
  for (var i = 0; i < data.filters.length; i++) {
    var item = data.filters[i];
    var filter = model._filters.add(item[1], item[2], item[3], item[4]);
    filter.ref(item[0]);
  }
  // Init and re-subscribe queries as appropriate
  model._initQueries(data.queries, data.contexts);

  return model;
};

util.serverRequire(__dirname + '/Racer.server.js');
