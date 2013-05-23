var Duplex = require('stream').Duplex;
var EventEmitter = require('events').EventEmitter;
var browserify = require('browserify');
var uglify = require('uglify-js');
var share = require('share');
var util = require('./util');
var Channel = require('./Channel');
var Model = require('./Model');

module.exports = Store;

function Store(racer, options) {
  this.racer = racer;
  this.modelOptions = options && options.modelOptions;
  this.server = options && options.server;
  this.shareClient = share.server.createClient({
    db: options && options.db
  , auth: null
  });
  this.on('client', function(client) {
    var socket = new ClientSocket(client);
    client.channel = new Channel(socket);
  });
}

util.mergeInto(Store.prototype, EventEmitter.prototype);

Store.prototype.use = util.use;

Store.prototype.createModel = function(options) {
  if (this.modelOptions) {
    options = (options) ?
      util.mergeInto(options, this.modelOptions) :
      this.modelOptions;
  }
  var model = new Model(this, options);
  this.emit('model', model);
  var stream = new Duplex({objectMode: true});
  model._createConnection(stream);
  this.shareClient.listen(stream);
  return model;
};

Store.prototype.modelMiddleware = function() {
  var store = this;
  function getModel() {
    var model = store.createModel({fetchOnly: true});
    this.getModel = function getModel() {
      return model;
    };
    return model;
  }
  function modelMiddleware(req, res, next) {
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
  var minify = options.minify || util.isProduction;
  // Add pseudo filenames and line numbers in browser debugging
  if (options.debug == null && !util.isProduction) {
    options.debug = true;
  }
  var b = browserify();

  b.require(__dirname + '/index', {expose: 'racer'});
  this.emit('bundle', b);
  b.add(files);

  if (minify) {
    b.bundle(options, function(err, code) {
      // Browserify will return multiple errors by calling the callback more
      // than once
      if (err) {
        cb(err);
        cb = function() {};
      }
      var minified = uglify.minify(code, {
        'fromString': true
      }).code;
      cb(null, minified);
    });
  } else {
    b.bundle(options, function(err, code) {
      // Browserify will return multiple errors by calling the callback more
      // than once
      if (err) {
        cb(err);
        cb = function() {};
      }
      cb(null, code);
    });
  }
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
