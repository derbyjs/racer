var Duplex = require('stream').Duplex;
var EventEmitter = require('events').EventEmitter;
var share = require('share');
var util = require('./util');
var Channel = require('./Channel');
var Model = require('./Model');
var browserify = require('browserify');
var uglify = require('uglify-js');
var convertSourceMap = require('convert-source-map');

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
  this.emit('modelStream', stream);

  model._createConnection(stream, this.logger);
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

Store.prototype.bundle = function(file, options, cb) {
  if (typeof options === 'function') {
    cb = options;
    options = null;
  }
  options || (options = {});
  options.debug = true;
  var minify = (options.minify == null) ? util.isProduction : options.minify;

  var b = browserify(options);
  b.require(__dirname + '/index', {expose: 'racer'});
  this.emit('bundle', b);
  b.add(file);

  b.bundle(options, function(err, source) {
    if (err) return cb(err);
    // Extract the source map, which Browserify includes as a comment
    var map = convertSourceMap.fromSource(source).toJSON();
    source = convertSourceMap.removeComments(source);
    if (!minify) return cb(null, source, map);

    options.fromString = true;
    options.outSourceMap = 'map';
    // If inSourceMap is a string it is assumed to be a filename, but passing
    // in as an object avoids the need to make a file
    options.inSourceMap = JSON.parse(map);
    var result = uglify.minify(source, options);

    // Uglify doesn't include the source content in the map, so copy over from
    // the map that browserify generates
    var mapObject = JSON.parse(result.map);
    mapObject.sourcesContent = options.inSourceMap.sourcesContent;
    cb(null, result.code, JSON.stringify(mapObject));
  });
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
