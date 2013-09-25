var Duplex = require('stream').Duplex;
var EventEmitter = require('events').EventEmitter;
var share = require('share');
var util = require('./util');
var Channel = require('./Channel');
var Model = require('./Model');
var bundle = require('./bundle');

module.exports = Store;

function Store(racer, options) {
  EventEmitter.call(this);
  this.racer = racer;
  this.modelOptions = options && options.modelOptions;
  this.shareClient = share.server.createClient(options);
  this.logger = options && options.logger;
  this.on('client', function(client) {
    var socket = new ClientSocket(client);
    client.channel = new Channel(socket);
  });
}

util.mergeInto(Store.prototype, EventEmitter.prototype);

Store.prototype.use = util.use;

Store.prototype.createModel = function(options, req) {
  if (this.modelOptions) {
    options = (options) ?
      util.mergeInto(options, this.modelOptions) :
      this.modelOptions;
  }
  var model = new Model(options);
  this.emit('model', model);
  var stream = new Duplex({objectMode: true});
  stream.isServer = true;

  model._createConnection(stream, this.logger);
  this.shareClient.listen(stream, req);

  return model;
};

Store.prototype.modelMiddleware = function() {
  var store = this;
  function modelMiddleware(req, res, next) {
    function getModel() {
      var model = store.createModel({fetchOnly: true}, req);
      this.getModel = function () {
        return model;
      };
      return model;
    }
    req.getModel = getModel;
    next();
  }
  return modelMiddleware;
};

Store.prototype.bundle = function(files, options, cb) {
  if (typeof options === 'function') {
    cb = options;
    options = {};
  }
  var store = this;
  options.configure = function(b) {
    b.require(__dirname + '/index', {expose: 'racer'});
    store.emit('bundle', b);
    b.add(files);
  };
  bundle(options, cb);
};

function ClientSocket(client) {
  this.client = client;
  var socket = this;
  client.on('message', function(data) {
    socket.onmessage(data);
  });
}
ClientSocket.prototype.send = function(data) {
  this.client.send(data);
};
