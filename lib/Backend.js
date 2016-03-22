var Backend = require('sharedb').Backend;
var util = require('./util');
var Model = require('./Model');

module.exports = RacerBackend;

function RacerBackend(racer, options) {
  Backend.call(this, options);
  this.racer = racer;
  this.modelOptions = options && options.modelOptions;
  this.on('bundle', function(browserify) {
    browserify.require(__dirname + '/index.js', {expose: 'racer'});
  });
}
RacerBackend.prototype = Object.create(Backend.prototype);

RacerBackend.prototype.createModel = function(options, req) {
  if (this.modelOptions) {
    options = (options) ?
      util.mergeInto(options, this.modelOptions) :
      this.modelOptions;
  }
  var model = new Model(options);
  this.emit('model', model);
  model.createConnection(this, req);
  return model;
};

RacerBackend.prototype.modelMiddleware = function() {
  var backend = this;
  function modelMiddleware(req, res, next) {
    req.model = backend.createModel({fetchOnly: true}, req);
    // DEPRECATED:
    req.getModel = function() {
      return req.model;
    };

    function closeModel() {
      res.removeListener('finish', closeModel);
      res.removeListener('close', closeModel);
      if (req.model) req.model.close();
      // DEPRECATED:
      req.getModel = getModelUndefined;
    }
    res.on('finish', closeModel);
    res.on('close', closeModel);

    next();
  }
  return modelMiddleware;
};

function getModelUndefined() {}
