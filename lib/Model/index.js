var uuid = require('node-uuid');
var util = require('../util');

Model.INITS = [];

module.exports = Model;

function Model(store, options) {
  this.store = store;
  var inits = Model.INITS;
  options || (options = {});
  for (var i = 0; i < inits.length; i++) {
    inits[i](this, options);
  }
}

Model.prototype.id = function() {
  return uuid.v4();
};

// Extend model on both server and client
require('./events');
require('./paths');
require('./connection');
require('./collections');
require('./mutators');
require('./setDiff');
require('./ref');
require('./refList');
require('./subscriptions');
require('./Query');
require('./contexts');
require('./fn');

// Extend model for server
util.serverRequire(__dirname + '/bundle');
util.serverRequire(__dirname + '/connection.server');
