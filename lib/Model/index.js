var uuid = require('node-uuid');
var racer = require('../racer');
var util = require('../util');

module.exports = Model;

// Extend model on both server and client
require('./events');
require('./scope');
require('./collections');
require('./mutators');
require('./connection');

// Extend model for server
util.serverRequire(__dirname + '/bundle');
util.serverRequire(__dirname + '/connection.server');

function Model() {
  this.flags || (this.flags = {});

  racer.emit('Model:init', this);
}

Model.prototype.id = function() {
  return uuid.v4();
};
