var SessionStore = require('connect').session.Store;

module.exports = RacerSessionStore;

/**
 * Initialize a new `RacerSessionStore`
 *
 * @param {Store} store is the racer store
 * @api public
 */
function RacerSessionStore (store) {
  this._model = store.createModel();
}

RacerSessionStore.prototype.__proto__ = SessionStore.prototype;

/**
 * Attempt to fetch session by the given `sid`.
 *
 * @param {String} sid
 * @param {Function} fn
 * @api public
 */
RacerSessionStore.prototype.get = function (sid, fn) {
  var model = this._model
    , sessPath = 'sessions.' + sid
    , session = model.get(sessPath);
  if (session) return fn(null, session);
  model.subscribe(sessPath, function (err, sessionModel) {
    if (err) return fn(err);
    return fn(null, sessionModel.get());
  });
};

/**
 * Commit the given `sess` object associated with the given `sid`.
 *
 * @param {String} sid
 * @param {Session} sess
 * @param {Function} fn
 * @api public
 */
RacerSessionStore.prototype.set = function (sid, sess, fn) {
  this._model.set('sessions.' + sid, sess);
  fn(null, sess);
};

/**
 * Destroy the session associated with the given `sid`.
 *
 * @param {String} sid
 * @api public
 */
RacerSessionStore.prototype.destroy = function (sid, fn) {
  var model = this._model
    , docPath = 'sessions.' + sid;
  model.del(docPath);
  model.unsubscribe(docPath, fn);
};

/**
 * Invoke the given callback `fn` with all active sessions.
 *
 * @param {Function} fn
 * @api public
 */
RacerSessionStore.prototype.all = function (fn) {
};

/**
 * Clear all sessions.
 *
 * @param {Function} fn
 * @api public
 */
RacerSessionStore.prototype.clear = function (fn) {
  model.del('sessions');
  fn();
};

/**
 * Fetch number of sessions.
 *
 * @param {Function} fn
 * @api public
 */
RacerSessionStore.prototype.length = function (fn) {
};
