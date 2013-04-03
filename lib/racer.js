var EventEmitter = require('events').EventEmitter;
var uuid = require('node-uuid');
var util = require('./util');

var racer = module.exports = new EventEmitter();

// For use by plugins
racer.Model = require('./Model');
racer.util = util;

racer.use = function use(plugin, options) {
  // Server-side plugins may be included via filename
  if (typeof plugin === 'string') {
    if (!util.isServer) return this;
    var _require = require;
    plugin = _require(plugin);
  }

  // Don't include a plugin more than once -- useful in tests where race
  // conditions exist regarding require and clearing require.cache
  var plugins = this._plugins || (this._plugins = []);
  if (plugins.indexOf(plugin) === -1) {
    plugins.push(plugin);
    plugin(this, options);
  }
  return this;
};

racer.uuid = function uuid() {
  return uuid.v4();
};

// This plugin is passed by string to prevent Browserify from including it
if (util.isServer) {
  racer.use(__dirname + '/racer.server');
}

racer
  .use(require('./mutators'))
  // .use(require('./refs'))

// The browser module must be included last, since it creates a model instance,
// before which all plugins should be included
if (!util.isServer) {
  racer.use(require('./racer.browser'));
}
