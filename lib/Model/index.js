var uuid = require('node-uuid');
var racer = require('../racer');
var util = require('../util');

module.exports = Model;

require('./events');
require('./scoped');
util.serverRequire(__dirname + '/bundle');

if (!util.isServer) require('./connection');

function Model() {
  this.flags || (this.flags = {});

  racer.emit('Model:init', this);
}

Model.prototype.id = function() {
  return uuid.v4();
};
