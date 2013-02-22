var fs = require('fs')
  , browserify = require('browserify')
  , socketioClient = require('socket.io-client')
  , uglify = require('uglify-js')
  , Store = require('./Store')
  , util = require('./util')
  , configuration = require('./configuration')

if (typeof browserify === 'function')
  browserify = new browserify();

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
  racer.io = {};
  racer.ioClient = {};

  var envs = ['server', process.env.NODE_ENV || 'development'];
  configuration.makeConfigurable(racer, envs);
  configuration.makeConfigurable(racer.io, envs);
  configuration.makeConfigurable(racer.ioClient, envs);

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
      var bundle = browserify.bundle(options);
      if (bundle.on) {
        var data = [value + ';'];
        bundle.on('data', function (chunk) {
          data.push(chunk);
        });
        bundle.on('end', function (err) {
          data = data.join('');
          callback(err, data);
        });
        return;
      }
      callback(err, value + ';' + bundle);
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
