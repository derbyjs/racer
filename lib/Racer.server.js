var Backend = require('./Backend');
var Racer = require('./Racer');

Racer.prototype.Backend = Backend;
Racer.prototype.version = require('../package').version;

Racer.prototype.createBackend = function(options) {
  var backend = new Backend(this, options);
  this.emit('backend', backend);
  return backend;
};
