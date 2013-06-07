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
require('./subscriptions');
require('./Query');
require('./contexts');
require('./fn');
require('./filter');
require('./refList');
// ref is at the *very* end because ref changes the effective order of events
// that event listeners see that are added after ref. So this makes it safer.
require('./ref');

// Extend model for server
util.serverRequire(__dirname + '/bundle');
util.serverRequire(__dirname + '/connection.server');
