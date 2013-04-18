var Model = require('./index');
var BCSocket = global.BCSocket;
var share = global.sharejs;

Model.prototype._createConnection = function() {
  this.socket = new BCSocket('/channel');
  this.shareConnection = new share.Connection(this.socket);
};

Model.prototype.subscribe = function() {

};

Model.prototype.subscribeDoc = function(collectionName, id, cb) {
  var doc = this.shareConnection.getOrCreate(collectionName, id);
  doc.incremental = true;
  this.getOrCreateDoc(collectionName, id, doc);
  doc.subscribe(function(err) {
    if (err) return cb(err);
    if (!doc.type) {
      doc.create('json0', cb);
    } else {
      cb();
    }
  });
};
