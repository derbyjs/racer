var fs = require('fs')
  , browserify = require('browserify')
  , socketioClient = require('socket.io-client')
  , uglify = require('uglify-js')
  , Store = require('./Store')
  , util = require('./util')
  , mergeAll = util.mergeAll
  , isProduction = util.isProduction;

exports = module.exports = plugin;
exports.decorate = 'racer';
exports.useWith = { server: true, browser: false };

function plugin (racer) {
  racer.version = require('../package').version;

  /* For use by all other plugins */
  mergeAll(racer.protected, {
    // TODO This is brittle if we change what is in ./queries/ later. Instead,
    // we should add a "protected" attribute to particular objects in these
    // directories, and then compile these objects into racer.protected
    queries: {
      QueryBuilder: require('./queries/QueryBuilder')
    , MemoryQuery: require('./queries/MemoryQuery')
    , QueryHub: require('./queries/QueryHub')
    , QueryNode: require('./queries/QueryNode')
    , PaginatedQueryNode: require('./queries/PaginatedQueryNode')
    }
  , diffMatchPatch: require('./diffMatchPatch')
  , Memory: require('./Memory')
  , path: require('./path')
  , Serializer: require('./Serializer')
  , Store: Store
  , transaction: require('./transaction.server')
  });

  /* Racer Server-side Configuration */

  racer.settings = { env: process.env.NODE_ENV || 'development' };

  racer.configure = function () {
    var envs = Array.prototype.slice.call(arguments, 0, arguments.length-1)
      , fn = arguments[arguments.length-1];
    if (envs[0] === 'all' || ~envs.indexOf(this.settings.env)) {
      fn.call(this);
    }
    return this;
  };

  racer.set = function (setting, value) {
    this.settings[setting] = value;
    return this;
  };

  racer.get = function (setting) { return this.settings[setting]; };

  racer.set('transports', ['websocket', 'xhr-polling']);

  racer.configure('production', function () {
    this.set('minify', true);
  });

  /* Racer built-in features */

  racer.createStore = function (options) {
    options || (options = {});
    options.racer = this;
    // TODO Provide full configuration for socket.io
    var store = new Store(options)
      , sockets, listen;
    if (sockets = options.sockets) {
      store.setSockets(sockets, options.socketUri);
    } else if (listen = options.listen) {
      store.listen(listen, options.namespace);
    }

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
      options.filter = this.get('minifyFilter') || uglify;
    }

    // Add pseudo filenames and line numbers in browser debugging
    if (! isProduction && options.debug != null) {
      options.debug = true;
    }

    socketioClient.builder(this.get('transports'), {minify: minify}, function (err, value) {
      callback(err, value + ';' + browserify.bundle(options));
    });
  };

  racer.registerAdapter = require('./adapters').registerAdapter;

  racer
    .use(require('./bundle/bundle.Model'))
    .use(require('./session/index'))
    .use(require('./adapters/db-memory'))
    .use(require('./adapters/journal-memory'))
    .use(require('./adapters/clientid-mongo'))
    .use(require('./adapters/clientid-redis'))
    .use(require('./adapters/clientid-rfc4122_v4'))

  racer.logPlugin = require('./log.server');
}
