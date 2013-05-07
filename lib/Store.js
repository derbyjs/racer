var Duplex = require('stream').Duplex;
var browserChannel = require('browserchannel').server;
var racer = require('./racer');
var Model = require('./Model');
var share = require('share');

module.exports = Store;

function Store(options) {
  options || (options = {});
  this.server = options.server;
  this.shareClient = share.server.createClient({
    db: options.db
  , auth: null
  });
  racer.emit('Store:init', this);
}

Store.prototype.createModel = function(options) {
  var model = new Model(options);
  var stream = new Duplex({objectMode: true});
  model._createConnection(stream);
  this.shareClient.listen(stream);
  return model;
};

Store.prototype.modelMiddleware = function() {
  var store = this;
  function getModel() {
    var model = store.createModel({fetchOnly: true});
    model.req = this;
    this.getModel = function() {
      return model;
    };
    return model;
  }
  return function modelMiddleware(req, res, next) {
    req.getModel = getModel;
    next();
  };
};

Store.prototype.socketMiddleware = function() {
  var store = this;
  var middleware = browserChannel({server: this.server}, function(client) {
    var stream = createBrowserChannelStream(client);
    store.shareClient.listen(stream);
  });
  return middleware;
};

function createBrowserChannelStream(client) {
  var stream = new Duplex({objectMode: true});

  stream._write = function _write(chunk, encoding, callback) {
    console.log('browser s->c ', chunk);
    client.send(chunk);
    callback();
  };
  // Ignore. You can't control the information, man!
  stream._read = function _read() {};

  client.on('message', function onMessage(data) {
    console.log('browser c->s ', data);
    stream.push(data);
  });

  stream.on('error', function onError() {
    client.stop();
  });

  return stream;
}
