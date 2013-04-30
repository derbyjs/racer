var Model = require('./index');
var share = require('share/src/client');

Model.prototype._createConnection = function() {
  var BCSocket = require('bcsocket').BCSocket;
  this.socket = new BCSocket('/channel');
  this.shareConnection = new share.Connection(this.socket);
};

Model.prototype.subscribe = function() {

};

Model.prototype.subscribeDoc = function(collectionName, id, cb) {
  var shareDoc = this._getOrCreateShareDoc(collectionName, id);
  this.getOrCreateDoc(collectionName, id, shareDoc);
  // If subscribe fails, we need to get notified of that failure somehow.
  shareDoc.subscribe();
  shareDoc.whenReady(function() {
    //if (err) return cb(err);
    if (!shareDoc.type) {
      shareDoc.create('json0', cb);
    } else {
      cb();
    }
  });
};

Model.prototype._getOrCreateShareDoc = function(collectionName, id) {
  var shareDoc = this.shareConnection.getOrCreate(collectionName, id);
  shareDoc.incremental = true;
  return shareDoc;
};
