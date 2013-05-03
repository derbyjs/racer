var racer = require('../racer');
var Model = require('./index');
var share = require('share/src/client');
var Query = require('./Query');
var util = require('../util');

racer.on('Model:init', function(model) {
  model._subscribedDocs = new SubscribedDocs;
});

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

Model.prototype.subscribe = function() {
  this._forSubscribable(arguments, 'subscribe');
};
Model.prototype.unsubscribe = function() {
  this._forSubscribable(arguments, 'unsubscribe');
};
Model.prototype._forSubscribable = function(argumentsObject, method) {
  var args = Array.prototype.slice.call(argumentsObject);
  var last = args[args.length - 1];
  var cb = (typeof last === 'function') ? args.pop() : this._defaultCallback;
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

Model.prototype.subscribeDoc = function(collectionName, id, cb) {
  if (!cb) cb = this._defaultCallback;
  var shareDoc = this._getOrCreateShareDoc(collectionName, id);
  var doc = this.getOrCreateDoc(collectionName, id, shareDoc);
  var previous = doc.get();

  var path = collectionName + '.' + id;
  if (this._subscribedDocs[path]) {
    // Already requested a subscribe, so just increment count of subscribers
    this._subscribedDocs[path]++;
  } else {
    // Subscribe request for unsubscribed document
    shareDoc.subscribe();
    this._subscribedDocs[path] = 1;
  }

  // TODO: If subscribe fails, we need to get notified of that failure somehow.

  var model = this;
  shareDoc.whenReady(function() {
    model.emit('load', [collectionName, id], [doc.get(), previous, model._pass]);
    cb();
  });
};

Model.prototype.unsubscribeDoc = function(collectionName, id, cb) {
  if (!cb) cb = this._defaultCallback;
  var path = collectionName + '.' + id;
  var count = this._subscribedDocs[path];

  // No effect if the document is not currently subscribed
  if (!count) return cb();

  // If there is only one remaining subscription, actually unsubscribe
  if (count === 1) {
    var shareDoc = this.shareConnection.get(collectionName, id);
    if (!shareDoc) {
      return cb(new Error('Share document not found for: ' + path));
    }
    shareDoc.unsubscribe();
    shareDoc.once('unsubscribed', function() {
      cb(null, 0);
    });
    delete this._subscribedDocs[path];
    // Remove the document from the local model
    var doc = this.getDoc(collectionName, id);
    var previous = doc && doc.get();
    this.collections[collectionName].remove(id);
    this.emit('unload', [collectionName, id], [previous, this._pass]);
    return;
  }

  // If there are more remaining subscriptions, only decrement the count and
  // callback with how many subscriptions are remaining
  count = --this._subscribedDocs[path];
  cb(null, count)
};

Model.prototype._getOrCreateShareDoc = function(collectionName, id, data) {
  var shareDoc = this.shareConnection.getOrCreate(collectionName, id, data);
  shareDoc.incremental = true;
  return shareDoc;
};
