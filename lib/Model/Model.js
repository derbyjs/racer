var uuid = require('node-uuid');

Model.INITS = [];

module.exports = Model;

function Model(store, options) {
  this.store = store;
  var inits = Model.INITS;
  options || (options = {});
  for (var i = 0; i < inits.length; i++) {
    inits[i](this, options);
  }
}

Model.prototype.id = function() {
  return uuid.v4();
};

Model.prototype._child = function() {
  return new ChildModel(this);
};

function ChildModel(model) {
  // TODO: Should nest the majority of these properties underneath a single
  // object, so that this isn't as brittle to changes and can be modular
  this.store = model.store;
  this._maxListeners = model._maxListeners;
  this._defaultCallback = model._defaultCallback;
  this._mutatorEventQueue = model._mutatorEventQueue;
  this.collections = model.collections;
  this._queries = model._queries;
  this._events = model._events;
  this.fetchOnly = model.fetchOnly;
  this.unloadDelay = model.unloadDelay;
  this._fetchedDocs = model._fetchedDocs;
  this._subscribedDocs = model._subscribedDocs;
  this._loadVersions = model._loadVersions;
  this._namedFns = model._namedFns;
  this._fns = model._fns;
  this._filters = model._filters;
  this._refLists = model._refLists;
  this._refs = model._refs;
  this.bundleTimeout = model.bundleTimeout;
  this._collectionsByNs = model._collectionsByNs;
  this.socket = model.socket;
  this.shareConnection = model.shareConnection;
  this.channel = model.channel;
  this._contexts = model._contexts;
  // These properties are specific to a child instance
  this._context = model._context;
  this._at = model._at;
  this._pass = model._pass;
  this._silent = model._silent;
}
ChildModel.prototype = new Model;
