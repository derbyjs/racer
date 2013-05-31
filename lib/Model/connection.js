var share = require('share/lib/client');
var Channel = require('../Channel');
var Model = require('./index');

Model.prototype._createConnection = function(bundle) {
  // Model#_createSocket should be defined by the socket plugin
  this.socket = this._createSocket(bundle);

  // The Share connection will bind to the socket by defining the onopen,
  // onmessage, etc. methods
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

  // Wrap the socket methods on top of Share's methods
  this._createChannel();
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

Model.prototype._createChannel = function() {
  this.channel = new Channel(this.socket);
};
