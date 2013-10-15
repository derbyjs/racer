var share = require('share');
var Model = require('./Model');

Model.prototype._createConnection = function(stream, logger) {
  var socket = new StreamSocket(stream, logger);
  this.root.socket = socket;
  this.root.shareConnection = new share.client.Connection(socket);
  socket.onopen();
  this._set(['$connection', 'state'], 'connected');
  this._createChannel();
};

/**
 * Wrapper to make a stream look like a BrowserChannel socket
 * @param {Stream} stream
 */
function StreamSocket(stream, logger) {
  this.stream = stream;
  this.logger = logger;
  var socket = this;
  stream._read = function _read() {};
  stream._write = function _write(chunk, encoding, callback) {
    socket.onmessage(chunk);
    if (logger) logger.write(chunk);
    callback();
  };
}
StreamSocket.prototype.send = function(data) {
  var copy = JSON.parse(JSON.stringify(data));
  this.stream.push(copy);
  if (this.logger) this.logger.write(copy);
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
