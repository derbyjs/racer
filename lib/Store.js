var Duplex = require('stream').Duplex;
var EventEmitter = require('events').EventEmitter;
var share = require('share');
var util = require('./util');
var Channel = require('./Channel');
var Model = require('./Model');

module.exports = Store;

function Store(racer, options) {
  EventEmitter.call(this);
  this.racer = racer;
  this.modelOptions = options && options.modelOptions;
  this.shareClient = options && share.server.createClient(options);
  this.logger = options && options.logger;
  this.on('client', function(client) {
    var socket = new ClientSocket(client);
    client.channel = new Channel(socket);
  });
  this.on('bundle', function(browserify) {
    browserify.require(__dirname + '/index.js', {expose: 'racer'});
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
  this.emit('modelStream', stream);

  model.createConnection(stream, this.logger);
  this.shareClient.listen(stream, req);

  return model;
};

Store.prototype.modelMiddleware = function() {
  var store = this;
  function modelMiddleware(req, res, next) {
    var model;

    function getModel() {
      if (model) return model;
      model = store.createModel({fetchOnly: true}, req);
      return model;
    }
    req.getModel = getModel;

    function closeModel() {
      res.removeListener('finish', closeModel);
      res.removeListener('close', closeModel);
      model && model.close();
    }
    res.on('finish', closeModel);
    res.on('close', closeModel);

    next();
  }
  return modelMiddleware;
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
