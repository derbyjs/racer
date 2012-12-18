// Server-side part of a main racer module is made as a plugin to it.

var fs = require('fs')
  , browserify = require('browserify')
  , socketioClient = require('socket.io-client')
  , uglify = require('uglify-js')
  , Store = require('./Store')
  , util = require('./util')

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
    queries: {
      QueryBuilder: require('./descriptor/query/QueryBuilder')
    , MemoryQuery: require('./descriptor/query/MemoryQuery')
    , QueryHub: require('./descriptor/query/QueryHub')
    , QueryNode: require('./descriptor/query/QueryNode')
    , PaginatedQueryNode: require('./descriptor/query/PaginatedQueryNode')
    }
  , Memory: require('./Memory')
  , path: require('./path')
  , Serializer: require('./Serializer')
  , Store: Store
  , transaction: require('./transaction.server')
  });

  /* Racer Server-side Configuration */

  function makeConfigurable (module) {
    module.settings || (module.settings = {});
    module.configure = function (env, callback) {
      if (typeof env === 'function') {
        callback = env;
        env = 'all';
      }
      if ((env === 'all') || (env === racer.get('env'))) {
        callback.call(this);
      }
      return this;
    };

    module.set = function (setting, value) {
      this.settings[setting] = value;
      return this;
    };
    module.enable = function (setting) {
      return this.set(setting, true);
    };
    module.disable = function (setting) {
      return this.set(setting, false);
    };

    module.get = function (setting) {
      return this.settings[setting];
    };
    module.enabled = function (setting) {
      return !!this.get(setting);
    };
    module.disabled = function (setting) {
      return !this.get(setting);
    };

    module.applyConfiguration = function (configurable) {
      for (var setting in this.settings) {
        configurable.set(setting, this.settings[setting]);
      };
    };
  }

  racer.settings = { env: process.env.NODE_ENV || 'development' };
  racer.io = {};
  racer.ioClient = {};
  [racer, racer.io, racer.ioClient].forEach(makeConfigurable);

  racer.io.configure(function () {
    racer.io.set('transports', ['websocket', 'xhr-polling']);
    racer.io.disable('browser client');
  });
  racer.io.configure('production', function () {
    racer.io.set('log level', 1);
  });
  racer.io.configure('development', function () {
    racer.io.set('log level', 0);
  });

  racer.ioClient.configure(function() {
    racer.ioClient.set('reconnection delay', 100);
    racer.ioClient.set('max reconnection attempts', 20);
  });

  racer.configure('production', function() {
    this.set('minify', true);
    this.set('minifyJs', function (source) {
      return uglify.minify(source, {fromString: true}).code;
    });
  });

  /* Racer built-in features */

  // ## Creating store on server
  //
  // Call `racer.createStore` to create process-wide store object on server.
  // This will create new Store object, call `listen` on it if corresponding
  // option will be set, emit 'createStore' event on `this` object (which can
  // be racer or derby object) and will return *store object*.
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
      options.filter = this.get('minifyJs');
    }

    // Add pseudo filenames and line numbers in browser debugging
    if (!util.isProduction && options.debug == null) {
      options.debug = true;
    }

    socketioClient.builder(this.io.get('transports'), {minify: minify}, function (err, value) {
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

  // since 0.3.12
  racer.logPlugin = require('./log.server');
}
