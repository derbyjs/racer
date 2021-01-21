var util = require('util');
var expect = require('chai').expect;

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
