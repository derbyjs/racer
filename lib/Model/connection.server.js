var share = require('share');
var Model = require('./Model');

Model.prototype.createConnection = function(stream, logger) {
  var socket = new StreamSocket(this, stream, logger);
  this.root.socket = socket;
  this.root.shareConnection = new share.client.Connection(socket);
  socket.onopen();
  this._set(['$connection', 'state'], 'connected');
  this._finishCreateConnection();
};

/**
 * Wrapper to make a stream look like a BrowserChannel socket
 * @param {Stream} stream
 */
function StreamSocket(model, stream, logger) {
  this.model = model;
  this.stream = stream;
  this.logger = logger;
  var socket = this;
  stream._read = function _read() {};
  stream._write = function _write(chunk, encoding, callback) {
    socket.onmessage({
      type: 'message',
      data: chunk
    });
    if (logger) {
      var src = model.shareConnection && model.shareConnection.id;
      logger.write({type: 'S->C', chunk: chunk, src: src});
    }
    callback();
  };
}
StreamSocket.prototype.send = function(data) {
  var copy = JSON.parse(JSON.stringify(data));
  this.stream.push(copy);
  var src = this.model.shareConnection && this.model.shareConnection.id;
  if (this.logger) {
    this.logger.write({type: 'C->S', chunk: copy, src: src});
  }
};
StreamSocket.prototype.close = function() {
  this.stream.end();
  this.stream.emit('close');
  this.stream.emit('end');
  this.onclose();
};
StreamSocket.prototype.onmessage = function() {};
StreamSocket.prototype.onclose = function() {};
StreamSocket.prototype.onerror = function() {};
StreamSocket.prototype.onopen = function() {};
StreamSocket.prototype.onconnecting = function() {};
