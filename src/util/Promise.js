var util = require('./index')
  , finishAfter = require('./async').finishAfter;

module.exports = Promise;

function Promise () {
  this.callbacks = [];
  this.resolved = false;
}

Promise.prototype = {
  resolve: function (err, value) {
    if (this.resolved) {
      throw new Error('Promise has already been resolved');
    }
    this.resolved = true;
    this.err = err;
    this.value = value;
    var callbacks = this.callbacks;
    for (var i = 0, l = callbacks.length; i < l; i++) {
      callbacks[i](err, value);
    }
    this.callbacks = [];
    return this;
  }

, on: function (callback) {
    if (this.resolved) {
      callback(this.err, this.value);
    } else {
      this.callbacks.push(callback);
    }
    return this;
  }

, clear: function () {
    this.resolved = false;
    delete this.value;
    delete this.err;
    return this;
  }
};

Promise.parallel = function (promises) {
  var composite = new Promise()
    , didErr;

  if (Array.isArray(promises)) {
    var compositeValue = []
      , remaining = promises.length;
    promises.forEach( function (promise, i) {
      promise.on( function (err, val) {
        if (didErr) return;
        if (err) {
          didErr = true;
          return composite.resolve(err);
        }
        compositeValue[i] = val;
        --remaining || composite.resolve(null, compositeValue);
      });
    });
  } else {
    var compositeValue = {}
      , remaining = Object.keys(promises).length;
    for (var k in promises) {
      var promise = promises[k];
      (function (k) {
        promise.on( function (err, val) {
          if (didErr) return;
          if (err) {
            didErr = true;
            return composite.resolve(err);
          }
          compositeValue[k] = val;
          --remaining || composite.resolve(null, compositeValue);
        });
      })(k);
    }
  }

  return composite;
};
