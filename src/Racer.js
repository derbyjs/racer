var EventEmitter = require('events').EventEmitter;
var Model = require('./Model');
var util = require('./util');

module.exports = Racer;

function Racer() {
  EventEmitter.call(this);
}

util.mergeInto(Racer.prototype, EventEmitter.prototype);

// Make classes accessible for use by plugins and tests
Racer.prototype.Model = Model;
Racer.prototype.util = util;

// Support plugins on racer instances
Racer.prototype.use = util.use;
Racer.prototype.serverUse = util.serverUse;

Racer.prototype.createModel = function(data) {
  var model = new Model();
  if (data) {
    model.createConnection(data);
    model.unbundle(data);
  }
  return model;
};

util.serverRequire(module, './Racer.server');
