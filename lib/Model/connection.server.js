var share = require('share');
var Model = require('./index');

Model.prototype._createConnection = function(stream) {
  this.socket = new Socket(stream);
  this.shareConnection = new share.client.Connection(this.socket);
  this.socket.onopen();
};

/**
 * Wrapper to make a stream look like a BrowserChannel socket
 * @param {Stream} stream
 */
function Socket(stream) {
  this.stream = stream;
  var socket = this;
  stream._read = function _read() {};
  stream._write = function _write(chunk, encoding, callback) {
    console.log('server s->c ', chunk);
    socket.onmessage(chunk);
    callback();
  };
}
Socket.prototype.send = function(data) {
  console.log('server c->s ', data);
  this.stream.push(data);
};
Socket.prototype.close =
  Socket.prototype.onmessage =
  Socket.prototype.onclose =
  Socket.prototype.onerror =
  Socket.prototype.onopen =
  Socket.prototype.onconnecting = function() {};
