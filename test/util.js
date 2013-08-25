var expect, inspect;

inspect = require('util').inspect;

exports.expect = expect = require('expect.js');

exports.calls = function(num, fn) {
  return function(done) {
    var n;
    if (num === (n = 0)) {
      done();
    }
    return fn.call(this, function() {
      if (++n >= num) {
        return done();
      }
    });
  };
};

exports.inspect = function(value, depth, showHidden) {
  if (depth == null) {
    depth = null;
  }
  if (showHidden == null) {
    showHidden = true;
  }
  return console.log(inspect(value, {
    depth: depth,
    showHidden: showHidden
  }));
};

expect.Assertion.prototype.NaN = function() {
  this.assert(this.obj !== this.obj, 'expected ' + inspect(this.obj) + ' to be NaN', 'expected ' + inspect(this.obj) + ' to not be NaN');
};

expect.Assertion.prototype["null"] = function() {
  this.assert(this.obj == null, 'expected ' + inspect(this.obj) + ' to be null or undefined', 'expected ' + inspect(this.obj) + ' to not be null or undefined');
};
