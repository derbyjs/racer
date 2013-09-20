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
// ref is at the *very* end because ref changes the effective order of events
// that event listeners see that are added after ref. So this makes it safer.
require('./ref');
