var racer = require('../racer');
var util = require('../util');
var Model = require('./index');

racer.on('Model:init', function(model) {
  model._bundlePromises = [];
  model._onLoad = [];
});

Model.prototype.bundle = function(callback) {
  racer.emit('Model:bundle', this);
  if (!this._bundlePromises.length) return finishBundle(this, callback);

  var bundlePromise = util.Promise.parallel(this._bundlePromises);

  var delay = racer.get('bundleTimeout');
  var timeout = setTimeout(function() {
    var err = new Error('Model bundling took longer than ' + delay + ' ms');
    bundlePromise.resolve(err);
  }, delay);

  var model = this;
  bundlePromise.on(function(err) {
    clearTimeout(timeout);
    if (err) return callback(err);
    finishBundle(model, callback);
  });
};

function finishBundle(model, callback) {
  var bundle = JSON.stringify([
    model._clientId
  , model._memory
  , model._count
  , model._onLoad
  , model._startId
  , model._ioUri
  , model._ioOptions
  , model.flags
  ]);
  callback(null, bundle);
  model._commit = errorOnCommit;
}

function errorOnCommit() {
  throw new Error('Model mutation performed after bundling for clientId: ' + this._clientId)
}
