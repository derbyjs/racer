// TODO Remove old code below
var mixinStore = require('./session.Store');

module.exports = function (store) {
  // The actual middleware is created by a factory so that the store can be set
  // later
  var fn = function (req, res, next) {
    if (!req.session) throw new Error('Missing session middleware');
    fn = sessionFactory(store);
    fn(req, res, next);
  };

  function middleware (req, res, next) {
    return fn(req, res, next);
  }

  middleware._setStore = function (_store) {
    store = _store;
  };

  return middleware;
};

function sessionFactory (store) {
  return function (req, res, next) {
    // Make sure to use only the unsalted id in data exposed to the client
    var sid = req.sessionID;

    var model = req.model || (req.model = store.createModel());
    model.subscribe( 'sessions.' + sid, function (err, session) {
      model.ref('_session', session);
      next();
    });
  };
}

///**
// * New Code
// */
//
//module.exports = plugin;
//
//function plugin (racer) {
//  racer.mixin(mixinStore);
//}
