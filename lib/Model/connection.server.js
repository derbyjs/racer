var share = require('share');
var Model = require('./index');
var util = require('util');

Model.prototype._createConnection = function(stream, logger) {
  this.socket = new StreamSocket(stream, logger);
  this.shareConnection = new share.client.Connection(this.socket);
  this.socket.onopen();
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
  this.stream.push(data);
  if (this.logger) this.logger.write(data);
};
StreamSocket.prototype.close =
  StreamSocket.prototype.onmessage =
  StreamSocket.prototype.onclose =
  StreamSocket.prototype.onerror =
  StreamSocket.prototype.onopen =
  StreamSocket.prototype.onconnecting = function() {};
