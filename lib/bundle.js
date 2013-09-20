var browserify = require('browserify');
var uglify = require('uglify-js');
var util = require('./util');

module.exports = function(options, cb) {
  var minify = options.minify || util.isProduction;
  // Add pseudo filenames and line numbers in browser debugging
  if (options.debug == null && !util.isProduction) {
    options.debug = true;
  }
  var b = browserify();

  options.configure && options.configure(b);

  if (minify) {
    b.bundle(options, function(err, code) {
      // Browserify will return multiple errors by calling the callback more
      // than once
      if (err) {
        cb(err);
        cb = function() {};
      }
      var minified = uglify.minify(code, {
        fromString: true
      , outSourceMap: 'minified.js.map'
      });
      cb(null, minified.code, minified.map);
    });

  } else {
    b.bundle(options, function(err, code) {
      // Browserify will return multiple errors by calling the callback more
      // than once
      if (err) {
        cb(err);
        cb = function() {};
      }
      cb(null, code);
    });
  }
};
