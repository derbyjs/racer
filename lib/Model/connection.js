var share = require('share/lib/client');
var Channel = require('../Channel');
var Model = require('./Model');
var LocalDoc = require('./LocalDoc');
var RemoteDoc = require('./RemoteDoc');

Model.prototype.createConnection = function(bundle) {
  // Model::_createSocket should be defined by the socket plugin
  this.root.socket = this._createSocket(bundle);

  // The Share connection will bind to the socket by defining the onopen,
  // onmessage, etc. methods
  var shareConnection = this.root.shareConnection = new share.Connection(this.root.socket);
  var segments = ['$connection', 'state'];
  var states = ['connecting', 'connected', 'disconnected', 'stopped'];
  var model = this;
  states.forEach(function(state) {
    shareConnection.on(state, function() {
      model._setDiff(segments, state);
    });
  });
  this._set(segments, 'connected');

  // Wrap the socket methods on top of Share's methods
  this._createChannel();
};

Model.prototype.connect = function() {
  this.root.socket.open();
};
Model.prototype.disconnect = function() {
  this.root.socket.close();
};
Model.prototype.reconnect = function() {
  this.disconnect();
  this.connect();
};
// Clean delayed disconnect
Model.prototype.close = function(cb) {
  cb = this.wrapCallback(cb);
  var model = this;
  this.whenNothingPending(function() {
    model.root.socket.close();
    cb();
  });
};

Model.prototype._createChannel = function() {
  this.root.channel = new Channel(this.root.socket);
};

Model.prototype._getOrCreateShareDoc = function(collectionName, id, data) {
  var shareDoc = this.root.shareConnection.get(collectionName, id, data);
  shareDoc.incremental = true;
  return shareDoc;
};

Model.prototype._getDocConstructor = function(name) {
  // Whether the collection is local or remote is determined by its name.
  // Collections starting with an underscore ('_') are for user-defined local
  // collections, those starting with a dollar sign ('$'') are for
  // framework-defined local collections, and all others are remote.
  var firstCharcter = name.charAt(0);
  var isLocal = (firstCharcter === '_' || firstCharcter === '$');
  return (isLocal) ? LocalDoc : RemoteDoc;
};

Model.prototype.hasPending = function() {
  return !!this._firstPendingDoc();
};

Model.prototype.whenNothingPending = function(cb) {
  var doc = this._firstPendingDoc();
  if (doc) {
    // If a document is found with a pending operation, wait for it to emit
    // that nothing is pending anymore, and then recheck all documents again.
    // We have to recheck all documents, just in case another mutation has
    // been made in the meantime as a result of an event callback
    var model = this;
    doc.shareDoc.once('nothing pending', function retryNothingPending() {
      process.nextTick(function(){
        model.whenNothingPending(cb);
      });
    });
    return;
  }
  // Call back when no Share documents have pending operations
  process.nextTick(cb);
};

Model.prototype._firstPendingDoc = function() {
  // Loop through all of this model's documents, and return the first document
  // encountered with a pending Share operation
  var collections = this.root.collections;
  for (var collectionName in collections) {
    var collection = collections[collectionName];
    for (var id in collection.docs) {
      var doc = collection.docs[id];
      if (doc.shareDoc && doc.shareDoc.hasPending()) {
        return doc;
      }
    }
  }
};
