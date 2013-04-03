var Duplex = require('stream').Duplex;
var browserChannel = require('browserchannel').server;
var share = require('share');
var racer = require('../racer');
var Model = require('../Model');

module.exports = Store;

function Store(options) {
  options || (options = {});
  this.server = options.server;
  this.shareClient = share.createClient({
    db: options.db
  , auth: null
  });
  racer.emit('Store:init', this);
}

Store.prototype.socketMiddleware = function() {
  var store = this;
  var middleware = browserChannel({server: this.server}, function(client) {
    console.log(client.id, client.address, client.headers.cookie)

    var stream = createBrowserChannelStream(client);
    store.shareClient.listen(stream);
  });
  return middleware;
};

Store.prototype.createModel = function() {
  var model = new Model();
  var stream = createDirectStream(model);
  this.shareClient.listen(stream);
  return model;
};

function createBrowserChannelStream(client) {
  var stream = new Duplex({objectMode: true});

  stream._write = function _write(chunk, encoding, callback) {
    console.log('s->c ', chunk);
    client.send(chunk);
    callback();
  };
  // Ignore. You can't control the information, man!
  stream._read = function _read() {};

  client.on('message', function onMessage(data) {
    console.log('c->s ', data);
    stream.push(data);
  });

  stream.on('error', function onError(msg) {
    client.stop();
  });

  return stream;
}

function createDirectStream(model) {
  var stream = new Duplex({objectMode: true});

  stream._write = function _write(chunk, encoding, callback) {
    console.log('direct s->c ', chunk);
    model.emit('message', chunk);
    callback();
  };
  stream._read = function _read() {};

  model._send = function _send(data) {
    console.log('direct c->s ', data);
    stream.push(data);
  };

  stream.on('error', function onError(msg) {
    console.log('direct stream error', msg)
  });

  return stream;
}
