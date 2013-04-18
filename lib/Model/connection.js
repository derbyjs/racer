var Model = require('./index');
var BCSocket = window.BCSocket;
var share = window.sharejs;

Model.prototype._createSocket = function() {
  var socket = new BCSocket('/channel');
  this.socket = socket;
  this.shareConnection = new share.Connection(socket);
  // this._send = function _send(message) {
  //   socket.send(message);
  // };
  // socket.onopen = function() {
  //   socket.send({hi: 'there'});
  // };
  // var model = this;
  // socket.onmessage = function(message) {
  //   model.emit('message', message);
  // };
}

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
