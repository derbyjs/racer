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
  this.socket = new BCSocket('/channel');
  this.shareConnection = new share.Connection(this.socket);
};

Model.prototype.subscribe = function() {
  var args = Array.prototype.slice.call(arguments);

  var last = args[args.length - 1];
  var cb = (typeof last === 'function') ? args.pop() : this._defaultCallback;
  var group = new util.AsyncGroup(cb);

  for (var i = 0; i < args.length; i++) {
    var item = args[i];

    if (item instanceof Query) {
      item.subscribe(group.add());
    } else {
      var segments = this._resolvePath(item);

      if (segments.length === 1) {
        // Make a query to an entire collection.
        var query = this.query(this, segments[0], {});
        query.subscribe(group.add());
      } else if (segments.length === 2) {
        this.subscribeDoc(segments[0], segments[1], group.add());
      } else {
        this.emit('error', new Error('Cannot subscribe to a path within a document: ' + item));
      }
    }
  }
};

// Subscribe to a doc or query
Model.prototype._subscribe = function(thing, cb) {

}

Model.prototype.subscribeDoc = function(collectionName, id, cb) {
  var shareDoc = this._getOrCreateShareDoc(collectionName, id);
  if (!cb) cb = this._defaultCallback;

  this.getOrCreateDoc(collectionName, id, shareDoc);

  var path = collectionName + '.' + id;
  if (!this._subscribedDocs[path]) {
    // Already requested a subscribe.
    shareDoc.subscribe();
    this._subscribedDocs[path] = true;
  }

  // If subscribe fails, we need to get notified of that failure somehow.
  shareDoc.whenReady(function() {
    //if (err) return cb(err);
    if (!shareDoc.type) {
      shareDoc.create('json0');
    }
    cb();
  });
};

Model.prototype._getOrCreateShareDoc = function(collectionName, id, data) {
  var shareDoc = this.shareConnection.getOrCreate(collectionName, id, data);
  shareDoc.incremental = true;
  return shareDoc;
};

