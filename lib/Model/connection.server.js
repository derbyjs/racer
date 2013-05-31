var share = require('share');
var Model = require('./index');
var util = require('util');

Model.prototype._createConnection = function(stream) {
  this.socket = new StreamSocket(stream);
  this.shareConnection = new share.client.Connection(this.socket);
  this.socket.onopen();
  this._set(['$connection', 'state'], 'connected');
  this._createChannel();
};

/**
 * Wrapper to make a stream look like a BrowserChannel socket
 * @param {Stream} stream
 */
function StreamSocket(stream) {
  this.stream = stream;
  var socket = this;
  stream._read = function _read() {};
  stream._write = function _write(chunk, encoding, callback) {
    socket.onmessage(chunk);
    callback();
  };
}
StreamSocket.prototype.send = function(data) {
  this.stream.push(data);
};
StreamSocket.prototype.close =
  StreamSocket.prototype.onmessage =
  StreamSocket.prototype.onclose =
  StreamSocket.prototype.onerror =
  StreamSocket.prototype.onopen =
  StreamSocket.prototype.onconnecting = function() {};
