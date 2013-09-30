module.exports = require('./Model');

// Extend model on both server and client
require('./events');
require('./paths');
require('./collections');
require('./mutators');
require('./setDiff');
require('./fn');
require('./filter');
require('./refList');
require('./ref');
