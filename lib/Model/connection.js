var racer = require('../racer');
var Model = require('./index');
var share = require('share/src/client');
var Query = require('./Query');
var util = require('../util');

racer.on('Model:init', function(model) {
  model._fetchedDocs = new FetchedDocs;
  model._subscribedDocs = new SubscribedDocs;
});

function FetchedDocs() {}
function SubscribedDocs() {}

Model.prototype._createConnection = function() {
  var BCSocket = require('bcsocket').BCSocket;
  this.socket = new BCSocket('/channel', {reconnect: true});
  this.shareConnection = new share.Connection(this.socket);
  var model = this;
  this.shareConnection.on('error', onShareConnectionError);
  function onShareConnectionError(err) {
    // Because we will automatically reconnect, ignore unkown session ID
    if (err === "Unknown session ID") return;
    if (typeof err === 'string') err = new Error(err);
    model.emit('error', err);
  }
};

Model.prototype.fetch = function() {
  this._forSubscribable(arguments, 'fetch');
};
Model.prototype.unfetch = function() {
  this._forSubscribable(arguments, 'unfetch');
};
Model.prototype.subscribe = function() {
  this._forSubscribable(arguments, 'subscribe');
};
Model.prototype.unsubscribe = function() {
  this._forSubscribable(arguments, 'unsubscribe');
};
Model.prototype._forSubscribable = function(argumentsObject, method) {
  if (Array.isArray(argumentsObject[0])) {
    var args = argumentsObject[0];
    var cb = argumentsObject[1] || this._defaultCallback;
  } else {
    var args = Array.prototype.slice.call(argumentsObject);
    var last = args[args.length - 1];
    var cb = (typeof last === 'function') ? args.pop() : this._defaultCallback;
  }
  var group = new util.AsyncGroup(cb);
  var docMethod = method + 'Doc';

  for (var i = 0; i < args.length; i++) {
    var item = args[i];
    if (item instanceof Query) {
      item[method](group.add());
    } else {
      var segments = this._resolvePath(item);
      if (segments.length === 1) {
        // Make a query to an entire collection.
        var query = this.query(this, segments[0], {});
        query[method](group.add());
      } else if (segments.length === 2) {
        this[docMethod](segments[0], segments[1], group.add());
      } else {
        var message = 'Cannot ' + method + ' to a path within a document: ' + item;
        this.emit('error', new Error(message));
      }
    }
  }
};

Model.prototype.fetchDoc = function(collectionName, id, cb, alreadyLoaded) {
  if (!cb) cb = this._defaultCallback;
  var doc = this.getOrCreateDoc(collectionName, id);
  var previous = doc.get();

  if (alreadyLoaded) {
    fetchDocCallback();
  } else {
    doc.shareDoc.fetch(fetchDocCallback);
  }
  var model = this;
  function fetchDocCallback(err) {
    if (err) return cb(err);
    model.emit('load', [collectionName, id], [doc.get(), previous, model._pass]);
    cb();
  }
  // Maintain a count of fetches so that we can unload the document when
  // there are no remaining fetches or subscribes for that document
  var path = collectionName + '.' + id;
  this._fetchedDocs[path] = (this._fetchedDocs[path] || 0) + 1;
};

Model.prototype.subscribeDoc = function(collectionName, id, cb) {
  if (!cb) cb = this._defaultCallback;

  var path = collectionName + '.' + id;
  if (this._subscribedDocs[path]) {
    // Already requested a subscribe, so just increment count of subscribers
    this._subscribedDocs[path]++;
    return;
  }

  // Subscribe if currently unsubscribed
  var model = this;
  var doc = this.getOrCreateDoc(collectionName, id);
  var previous = doc.get();
  doc.shareDoc.subscribe(subscribeDocCallback);
  this._subscribedDocs[path] = 1;
  function subscribeDocCallback(err) {
    if (err) return cb(err);
    model.emit('load', [collectionName, id], [doc.get(), previous, model._pass]);
    cb();
  }
};

Model.prototype.unfetchDoc = function(collectionName, id, cb) {
  if (!cb) cb = this._defaultCallback;
  var path = collectionName + '.' + id;
  var count = this._fetchedDocs[path];

  // No effect if the document has no fetch count
  if (!count) return cb();

  count = --this._fetchedDocs[path];
  if (count === 0) {
    delete this._fetchedDocs[path];
    this._maybeUnloadDoc(collectionName, id, path);
  }
  cb(null, count);
};

Model.prototype.unsubscribeDoc = function(collectionName, id, cb) {
  if (!cb) cb = this._defaultCallback;
  var path = collectionName + '.' + id;
  var count = this._subscribedDocs[path];

  // No effect if the document is not currently subscribed
  if (!count) return cb();

  if (count > 1) {
    // If there are more remaining subscriptions, only decrement the count and
    // callback with how many subscriptions are remaining
    count = --this._subscribedDocs[path];
    cb(null, count);
    return;
  }

  // If there is only one remaining subscription, actually unsubscribe
  var shareDoc = this.shareConnection.get(collectionName, id);
  if (!shareDoc) {
    return cb(new Error('Share document not found for: ' + path));
  }
  shareDoc.unsubscribe(unsubscribeDocCallback);
  function unsubscribeDocCallback(err) {
    if (err) return cb(err);
    cb(null, 0);
  }
  delete this._subscribedDocs[path];
  this._maybeUnloadDoc(collectionName, id, path);
};

Model.prototype._maybeUnloadDoc = function(collectionName, id, path) {
  var doc = this.getDoc();
  if (!doc) return;
  // Remove the document from the local model if it no longer has any
  // remaining fetches or subscribes
  if (this._fetchedDocs[path] || this._subscribedDocs[path]) return;
  var previous = doc.get();
  this.collections[doc.collectionName].remove(id);
  this.emit('unload', [doc.collectionName, doc.id], [previous, this._pass]);
};

Model.prototype._getOrCreateShareDoc = function(collectionName, id, data) {
  var shareDoc = this.shareConnection.getOrCreate(collectionName, id, data);
  shareDoc.incremental = true;
  return shareDoc;
};
