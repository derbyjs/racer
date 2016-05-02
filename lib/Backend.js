var path = require('path');
var Backend = require('sharedb').Backend;
var Model = require('./Model');
var util = require('./util');

module.exports = RacerBackend;

function RacerBackend(racer, options) {
  Backend.call(this, options);
  this.racer = racer;
  this.modelOptions = options && options.modelOptions;
  this.on('bundle', function(browserify) {
    var racerPath = path.join(__dirname, 'index.js');
    browserify.require(racerPath, {expose: 'racer'});
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
    // Do not add a model to the request if one has been added already
    if (req.model) return next();

    // Create a new model for this request
    req.model = backend.createModel({fetchOnly: true}, req);
    // DEPRECATED:
    req.getModel = function() {
      console.warn('Warning: req.getModel() is deprecated. Please use req.model instead.');
      return req.model;
    };

    // Close the model when this request ends
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
