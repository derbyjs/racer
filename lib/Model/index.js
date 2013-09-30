module.exports = require('./Model');
var util = require('../util');

// Extend model on both server and client //
require('./events');
require('./paths');
require('./collections');
require('./mutators');
require('./setDiff');

require('./connection');
require('./subscriptions');
require('./Query');
require('./contexts');

require('./fn');
require('./filter');
require('./refList');
require('./ref');

// Extend model for server //
util.serverRequire(__dirname + '/bundle');
util.serverRequire(__dirname + '/connection.server');
