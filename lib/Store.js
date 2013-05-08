var Duplex = require('stream').Duplex;
var EventEmitter = require('events').EventEmitter;
var browserify = require('browserify');
var Model = require('./Model');
var share = require('share');
var util = require('./util');

module.exports = Store;

function Store(racer, options) {
  this.racer = racer;
  this.modelOptions = options && options.modelOptions;
  this.server = options && options.server;
  this.shareClient = share.server.createClient({
    db: options && options.db
  , auth: null
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
  var model = new Model(options);
  this.emit('model', this);
  var stream = new Duplex({objectMode: true});
  model._createConnection(stream);
  this.shareClient.listen(stream);
  return model;
};

Store.prototype.modelMiddleware = function() {
  var store = this;
  return function modelMiddleware(req, res, next) {
    req.getModel = function getModel() {
      var model = store.createModel({fetchOnly: true});
      model.on('error', function onModelError(err) {
        if (!(err instanceof Error)) err = new Error(err);
        next(err);
      });
      this.getModel = function getModel() {
        return model;
      };
      return model;
    };
    next();
  };
};

Store.prototype.bundle = function(files, options, callback) {
  if (typeof options === 'function') {
    callback = options;
    options = {};
  }

  var minify = options.minify || util.isProduction
  if (minify) {
    // TODO: Add uglify transform
  }

  // Add pseudo filenames and line numbers in browser debugging
  if (!util.isProduction && options.debug == null) {
    options.debug = true;
  }

  var b = browserify(files);
  b.require(__dirname + '/index', {expose: 'racer'});
  this.emit('bundle', b);
  b.bundle(options, callback);
};
