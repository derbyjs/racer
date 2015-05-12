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
  var model = this;
  var shareConnection = this.root.shareConnection = new share.Connection(this.root.socket);
  var states = ['connecting', 'connected', 'disconnected', 'stopped'];
  states.forEach(function(state) {
    shareConnection.on(state, function(reason) {
      model._setDiff(['$connection', 'state'], state);
      model._setDiff(['$connection', 'reason'], reason);
    });
  });
  this._set(['$connection', 'state'], 'connected');

  this._finishCreateConnection();
};

Model.prototype._finishCreateConnection = function() {
  var model = this;
  this.shareConnection.on('error', function(err, data) {
    model._emitError(err, data);
  });
  // Share docs can be created by queries, so we need to register them
  // with Racer as soon as they are created to capture their events
  this.shareConnection.on('doc', function(shareDoc) {
    model.getOrCreateDoc(shareDoc.collection, shareDoc.name);
  });

  this.root.channel = new Channel(this.root.socket);
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

Model.prototype._isLocal = function(name) {
  // Whether the collection is local or remote is determined by its name.
  // Collections starting with an underscore ('_') are for user-defined local
  // collections, those starting with a dollar sign ('$'') are for
  // framework-defined local collections, and all others are remote.
  var firstCharcter = name.charAt(0);
  return firstCharcter === '_' || firstCharcter === '$';
};

Model.prototype._getDocConstructor = function(name) {
  return (this._isLocal(name)) ? LocalDoc : RemoteDoc;
};

Model.prototype.hasPending = function() {
  return !!this._firstShareDoc(hasPending);
};

Model.prototype.hasWritePending = function() {
  return !!this._firstShareDoc(hasWritePending);
};

Model.prototype.whenNothingPending = function(cb) {
  var shareDoc = this._firstShareDoc(hasPending);
  if (shareDoc) {
    // If a document is found with a pending operation, wait for it to emit
    // that nothing is pending anymore, and then recheck all documents again.
    // We have to recheck all documents, just in case another mutation has
    // been made in the meantime as a result of an event callback
    var model = this;
    shareDoc.once('nothing pending', function retryNothingPending() {
      process.nextTick(function(){
        model.whenNothingPending(cb);
      });
    });
    return;
  }
  // Call back when no Share documents have pending operations
  process.nextTick(cb);
};

function hasPending(shareDoc) {
  return shareDoc.hasPending();
}
function hasWritePending(shareDoc) {
  return shareDoc.inflightData != null || !!shareDoc.pendingData.length;
}

Model.prototype._firstShareDoc = function(fn) {
  // Loop through all of the documents on the share connection, and return the
  // first document encountered with that matches the provided test function
  var collections = this.root.shareConnection.collections;
  for (var collectionName in collections) {
    var collection = collections[collectionName];
    for (var id in collection) {
      var shareDoc = collection[id];
      if (shareDoc && fn(shareDoc)) {
        return shareDoc;
      }
    }
  }
};
