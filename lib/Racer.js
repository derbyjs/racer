var EventEmitter = require('events').EventEmitter;
var Model = require('./Model');
var util = require('./util');

module.exports = Racer;

function Racer() { EventEmitter.call(this); }

util.mergeInto(Racer.prototype, EventEmitter.prototype);

// Make classes accessible for use by plugins and tests
Racer.prototype.Model = Model;
Racer.prototype.util = util;

// Support plugins on racer instances
Racer.prototype.use = util.use;

Racer.prototype.init = function(data) {
  var racer = this;

  process.env.NODE_ENV = data.nodeEnv;

  // Init is executed async so that plugins can extend Racer even if they are
  // included after the main entry point in the bundle
  process.nextTick(function() {
    var model = new Model;

    model._createConnection(data);

    racer.emit('model', model);

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

    // TODO: Support re-init when there are contexts other than root
    var context = data.contexts.root;
    // Re-subscribe to document subscriptions
    for (var path in context.subscribedDocs) {
      var segments = path.split('.');
      model.subscribeDoc(segments[0], segments[1]);
      model._subscribedDocs[path] = context.subscribedDocs[path];
    }
    // Init fetchedDocs counts
    for (var path in context.fetchedDocs) {
      model._fetchedDocs[path] = context.fetchedDocs[path];
    }

    var silentModel = model.silent();
    // Re-create refs
    for (var i = 0; i < data.refs.length; i++) {
      var item = data.refs[i];
      silentModel.ref(item[0], item[1]);
    }
    // Re-create refLists
    for (var i = 0; i < data.refLists.length; i++) {
      var item = data.refLists[i];
      silentModel.refList(item[0], item[1], item[2], item[3]);
    }
    // Re-create fns
    for (var i = 0; i < data.fns.length; i++) {
      var item = data.fns[i];
      silentModel.start.apply(silentModel, item);
    }
    // Re-create filters
    for (var i = 0; i < data.filters.length; i++) {
      var item = data.filters[i];
      var filter = silentModel._filters.add(item[0], item[1], item[2]);
      filter.ref(item[3]);
    }
    // Init and re-subscribe queries as appropriate
    model._initQueries(data.queries);

    racer._model = model;
    racer.emit('ready', model);
  });
  return this;
};

Racer.prototype.ready = function(cb) {
  if (this._model) {
    // Callback async in case the code depends on scripts included after in
    // the bundle and is gated by a ready
    process.nextTick(function() {
      cb(this._model);
    });
    return;
  }
  this.once('ready', cb);
};

util.serverRequire(__dirname + '/Racer.server.js');
