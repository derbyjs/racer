var share = require('share/src/client');
var Model = require('./index');

Model.prototype._createConnection = function(bundle) {
  // Model#_createSocket should be defined by the socket plugin
  this.socket = this._createSocket(bundle);
  var shareConnection = this.shareConnection = new share.Connection(this.socket);
  var segments = ['$connection', 'state'];
  var states = ['connecting', 'connected', 'disconnected', 'stopped'];
  var model = this;
  states.forEach(function(state) {
    shareConnection.on(state, function() {
      model._set(segments, state);
    });
  });
  this._set(segments, 'connected');
};

Model.prototype.connect = function() {
  this.socket.open();
};
Model.prototype.disconnect = function() {
  this.socket.close();
};
Model.prototype.reconnect = function() {
  this.disconnect();
  this.connect();
};
