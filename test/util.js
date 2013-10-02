var util = require('util');
var expect = require('expect.js');

exports.expect = expect;

// For Mocha
exports.calls = function(num, fn) {
  return function(done) {
    if (num === 0) done();
    var n = 0;
    fn.call(this, function() {
      if (++n >= num) done();
    });
  };
};

exports.inspect = function(value, depth, showHidden) {
  if (depth == null) depth = null;
  if (showHidden == null) showHidden = true;
  console.log(util.inspect(value, {depth: depth, showHidden: showHidden}));
};

expect.Assertion.prototype.NaN = function() {
  this.assert(this.obj !== this.obj,
    'expected ' + util.inspect(this.obj) + ' to be NaN',
    'expected ' + util.inspect(this.obj) + ' to not be NaN'
  );
};

expect.Assertion.prototype.null = function() {
  this.assert(this.obj == null,
    'expected ' + util.inspect(this.obj) + ' to be null or undefined',
    'expected ' + util.inspect(this.obj) + ' to not be null or undefined'
  );
};
