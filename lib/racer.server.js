var browserify = require('browserify');
// var uglify = require('uglify-js');
var share = require('share');
var Store = require('./Store');
var util = require('./util');
var configuration = require('./configuration');

module.exports = plugin;

function plugin(racer) {
  racer.version = require('../package').version;

  // For use by plugins
  racer.Store = Store;

  var envs = ['server', process.env.NODE_ENV || 'development'];
  configuration.makeConfigurable(racer, envs);

  racer.configure(function() {
    // racer.set('minifyJs', function (source) {
    //   return uglify.minify(source, {fromString: true}).code;
    // });
    racer.set('bundleTimeout', 1000);
  });
  racer.configure('production', function() {
    this.set('minify', true);
  });

  /* Racer built-in features */

  racer.createStore = function (options) {
    return new Store(options);
  };

  racer.db = share.db;

  racer.bundle = bundle;
}

/**
 * Returns a string of JavaScript representing a browserify bundle and the
 * socket.io client-side code.
 *
 * Options:
 *   minify: Set to truthy to minify the JavaScript
 *
 *   Passed to browserify:
 *     entry: e.g., __dirname + '/client.js'
 *     filter: defaults to uglify if minify is true
 *     debug: true unless in production
 */
function bundle(files, options, callback) {
  if (typeof options === 'function') {
    callback = options;
    options = {};
  }
  var minify = options.minify || this.get('minify');
  if (minify) {
    // TODO: Add uglify transform
  }

  // Add pseudo filenames and line numbers in browser debugging
  if (!util.isProduction && options.debug == null) {
    options.debug = true;
  }

  var b = browserify(files);
  var bcPath = require.resolve('browserchannel/dist/bcsocket-uncompressed');
  b.require(bcPath, {expose: 'bcsocket'});
  this.emit('beforeBundle', b);
  b.bundle(options, callback);
}
