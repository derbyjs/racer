// This is the main module of the `racer` package.
//
// After creating aforementioned object, `./plugin` module is merged into it,
// same with object literal consisting of: `version`, `isServer` & `isClient`
// properties, links to `./util` and `./transaction` modules and `uuid`
// function. So exports from `./plugin` module and specified properties can be
// used right from `racer` module's exports (and thus from `derby` module's
// exports).

var util = require('./util')
  , mergeAll = util.mergeAll
  , isServer = util.isServer
  , isClient = !isServer;

// This module is intended to be run on server and a broad rage of browsers, so
// it uses `es5-shim` package to shim some new APIs of the ECMAScript 5 when
// run on client.
if (isClient) require('es5-shim');

// The core pattern used for extending the racer object is a *racer plugin*.
// The [`plugin`](plugin.html) module exports an object which represents an
// interface for making pluggable objects. See `plugin` module for details and
// additional responsibilities on the module.
var EventEmitter = require('events').EventEmitter
  , plugin = require('./plugin')
  , uuid = require('node-uuid');

// Module eports *racer object* which is an instance of `EventEmitter` extended
// by `plugin` interface and some other properties.
var racer = module.exports = new EventEmitter();

mergeAll(racer, plugin, {
  version: require('../package.json').version
, isServer: isServer
, isClient: isClient
, protected: {
    Model: require('./Model')
  }
, util: util
, uuid: function () {
    return uuid.v4();
  }
, transaction: require('./transaction')
});

// Note that this plugin is passed by string to prevent Browserify from
// including it
if (isServer) {
  racer.use(__dirname + '/racer.server');
}

racer
  .use(require('./mutators'))
  .use(require('./refs'))
  .use(require('./pubSub'))
  .use(require('./computed'))
  .use(require('./descriptor'))
  .use(require('./context'))
  .use(require('./txns'))
  .use(require('./reconnect'));

if (isServer) {
  racer.use(__dirname + '/adapters/pubsub-memory');
  racer.use(__dirname + '/accessControl')
  racer.use(__dirname + '/hooks')
}

// The browser module must be included last, since it creates a model instance,
// before which all plugins should be included
if (isClient) {
  racer.use(require('./racer.browser'));
}
