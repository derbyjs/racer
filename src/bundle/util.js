var uglify = require('uglify-js')
  , isProduction = require('../util').isProduction

module.exports = {
  bundledFunction: function (fn) {
    fn = fn.toString();
    if (isProduction) {
      // Uglify can't parse a naked function. Executing it allows Uglify to
      // parse it properly
      var uglified = uglify('(' + fn + ')()');
      fn = uglified.slice(1, -3);
    }
    return fn;
  }

, unbundledFunction: function (fnStr) {
    return (new Function('return ' + fnStr + ';'))();
  }
};
