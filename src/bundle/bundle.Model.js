var Promise = require('../util/Promise');

exports = module.exports = plugin;
exports.useWith = { server: true, browser: true };
exports.decorate = 'racer';

function plugin (racer) {
  var BUNDLE_TIMEOUT = racer.get('bundle timeout') ||
    racer.set('bundle timeout', 1000);
  mixin.static = { BUNDLE_TIMEOUT: BUNDLE_TIMEOUT };
  racer.mixin(mixin);
}

var mixin = {
  type: 'Model'

, events: {
    init: function (model) {
      model._bundlePromises = [];
      model._onLoad = [];
    }
  }

, server: {
    // What the end-developer calls on the server to bundle the app up to send
    // with a response
    bundle: function (callback) {
      var self = this;
      function addToBundle (key) {
        self._onLoad.push(Array.prototype.slice.call(arguments));
      }
      // TODO Only pass addToBundle to the event handlers
      this.mixinEmit('bundle', this, addToBundle);
      var timeout = setTimeout(onBundleTimeout, mixin.static.BUNDLE_TIMEOUT);
      Promise.parallel(this._bundlePromises).on( function () {
        clearTimeout(timeout);
        self._bundle(callback);
      });
    }

  , _bundle: function (callback) {
      callback(JSON.stringify([this._clientId, this._memory, this._count, this._onLoad, this._startId, this._ioUri]));
      this._commit = errorOnCommit;
    }
  }
};

function onBundleTimeout () {
  throw new Error('Model bundling took longer than ' + mixin.static.BUNDLE_TIMEOUT + ' ms');
}

function errorOnCommit () {
  throw new Error('Model mutation performed after bundling for clientId: ' + this._clientId)
}
