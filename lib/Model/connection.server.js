var share = require('share');
var Model = require('./index');

Model.prototype._createConnection = function(stream) {
  console.log('ajksdfhkahfskljshdfahsfkhskjdhf');
  this.socket = new StreamSocket(stream);
  this.shareConnection = new share.client.Connection(this.socket);
  this.socket.onopen();
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
    console.log('server s->c ', chunk);
    socket.onmessage(chunk);
    callback();
  };
}
StreamSocket.prototype.send = function(data) {
  console.log('server c->s ', data);
  this.stream.push(data);
};
StreamSocket.prototype.close =
  StreamSocket.prototype.onmessage =
  StreamSocket.prototype.onclose =
  StreamSocket.prototype.onerror =
  StreamSocket.prototype.onopen =
  StreamSocket.prototype.onconnecting = function() {};
