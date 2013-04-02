var fs = require('fs')
  , browserify = require('browserify')
  , socketioClient = require('socket.io-client')
  , uglify = require('uglify-js')
  , Store = require('./Store')
  , util = require('./util')
  , configuration = require('./configuration')

exports = module.exports = plugin;
exports.decorate = 'racer';
exports.useWith = { server: true, browser: false };

function plugin (racer) {
  racer.version = require('../package').version;

  /* For use by all other plugins */
  util.mergeAll(racer.protected, {
    // TODO This is brittle if we change what is in ./queries/ later. Instead,
    // we should add a "protected" attribute to particular objects in these
    // directories, and then compile these objects into racer.protected
    Store: Store
  });

  var envs = ['server', process.env.NODE_ENV || 'development'];
  configuration.makeConfigurable(racer, envs);

  racer.configure(function() {
    racer.set('minifyJs', function (source) {
      return uglify.minify(source, {fromString: true}).code;
    });
  });
  racer.configure('production', function() {
    this.set('minify', true);
  });

  /* Racer built-in features */

  racer.createStore = function (options) {
    options || (options = {});
    options.racer = this;
    // TODO Provide full configuration for socket.io
    var store = new Store(options)

    this.emit('createStore', store);
    return store;
  };

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
  racer.js = function (options, callback) {
    if (typeof options === 'function') {
      callback = options;
      options = {};
    }
    var minify = options.minify || this.get('minify');
    if (minify && !options.filter) {
      options.filter = this.get('minifyJs');
    }

    // Add pseudo filenames and line numbers in browser debugging
    if (!util.isProduction && options.debug == null) {
      options.debug = true;
    }

    var browserChannelFilename = require.resolve('browserchannel/dist/bcsocket');
    console.log(browserChannelFilename)
    fs.readFile(browserChannelFilename, 'utf-8', function(err, value) {
      callback(err, value + ';' + browserify.bundle(options));
    });
  };

  racer
    .use(require('./bundle/bundle.Model'))
    // .use(require('./session/index'))
}
