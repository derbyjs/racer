var util = require('./util');
var mergeAll = util.mergeAll;

var EventEmitter = require('events').EventEmitter;
var plugin = require('./plugin');
var uuid = require('node-uuid');

var racer = module.exports = new EventEmitter();

mergeAll(racer, plugin, {
  version: require('../package.json').version
, isServer: util.isServer
, protected: {
    Model: require('./Model')
  }
, util: util
, uuid: function () {
    return uuid.v4();
  }
});

// Note that this plugin is passed by string to prevent Browserify from
// including it
if (util.isServer) {
  racer.use(__dirname + '/racer.server');
}

racer
  .use(require('./mutators'))
  // .use(require('./refs'))

// The browser module must be included last, since it creates a model instance,
// before which all plugins should be included
if (!util.isServer) {
  require('es5-shim');
  racer.use(require('./racer.browser'));
}
