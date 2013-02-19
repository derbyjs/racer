var connect = require('connect')
  , Cookie = require('connect/lib/middleware/session/cookie')
  , parseSignedCookies = connect.utils.parseSignedCookies
  , parseSignedCookie = connect.utils.parseSignedCookie
  , createSessionMiddleware = connect.session
  , MemoryStore = createSessionMiddleware.MemoryStore
  , cookie = require('cookie')
  , finishAfter = require('../util/async').finishAfter
  ;

module.exports = {
  type: 'Store'

, events: {
    init: function (store) {
      // Maps sessionId -> [sockets...]
      // We need this to determine the sockets from which to remove the
      // session, whenever a session is destroyed.
      store._socketsBySessionId = {};
    }

  , socketio: function (store, sio) {
      return setupSocketAuth.call(this, store, sio);
    }

  , socket: onSocketConnection
  }

, proto: {
    sessionMiddleware: sessionMiddleware
  , modelMiddleware: modelMiddleware
  }
}

/**
 * Returns a connect middleware function(req, res, next) that handles
 * session creation and management.
 *
 * @param {Object} opts
 * @return {Function} a connect middleware function
 * @api public
 */
function sessionMiddleware(opts) {
  opts || (opts = {});
  this.usingSessions = true;
  if (this.io) {
    setupSocketAuth(this, this.io);
  }

  // The following properties are used in setupSocketAuth
  this._sessionKey = opts.key || (opts.key = 'connect.sid');
  this._sessionSecret = opts.secret;

  // Use in-memory sticky sessions as the option of first resort
  // TODO Ensure that up and node-http-proxy route requests to the proper
  // machine. Each of these upstream sites can check the persistent session
  // store to see which machine & process to route it to. If the machine or
  // process is down, then the load balancer/up should re-route the request to
  // a different process, with instructions to load the persistent store into
  // a sticky session at the new process site.
  var sessionStore = this._sessionStore = new MemoryStore;

  // But also (optional) persistent sessions in case of server restarts
  var persistentStore = opts.store;

  opts.store = sessionStore;

  patchSessionStore(sessionStore, this, persistentStore);

  this.on('createRequestModel', function (req, model) {
    var session = model.session = req.session;
    var userId = session.userId || session.auth && session.auth.userId;
    if (userId) model.set('_userId', userId);
  });

  return createSessionMiddleware(opts);
}

/**
 * Returns a connect middleware function(req, res, next) that adds a getModel
 * method to each req. Note that getModel must return the same model if called
 * multiple times for the same request and the same store.
 *
 * @param {Object} opts
 * @config {String|Function} [opts.socketHostname] is the hostname that
 *    socket.io connects to from the browser. This is useful for by-passing the
 *    connection per domain limit in browsers. For example, assign a Function
 *    that generates a random hostname per request, where the subdomain is
 *    randomly chosen.
 * @return {Function} a connect middleware function
 * @api public
 */
function modelMiddleware(opts) {
  opts = opts || {};
  var socketHostname = opts.socketHostname;

  var store = this;
  function getModel() {
    var model = this._racerModel;
    if (model && model.store === store) {
      return model;
    }
    var opts = {};
    if (socketHostname) {
      opts._ioUri = (typeof socketHostname === 'function')
                  ? socketHostname()
                  : socketHostname;
    }
    model = this._racerModel = store.createModel(opts);
    // model.req exposes headers of the request associated with
    // this server-side model
    model.req = this;

    store.emit('createRequestModel', this, model);
    return model;
  }
  return function modelMiddleware(req, res, next) {
    req.getModel = getModel;
    next();
  }
}

/**
 * Add additional handshake logic that converts the handshake request's cookie
 * into an express session. This session is attached to the socket's handshake
 * object.
 *
 * This session is later assigned to the socket that can be used to make
 * decisions about how to process subsequent messages over the socket.
 *
 * @param {Store} store
 * @param {socketio.Manager} io
 * @api private
 */
function setupSocketAuth (store, io) {
  if (! store.usingSessions || store.didSetupAuth) return;
  store.didSetupAuth = true;
  // Sets authorization callback for ALL socketio namespaces
  io.set('authorization', function (handshake, accept) {
    var sessStore = store._sessionStore;
    if (! sessStore) {
      return accept(null, false);  // No session store
    }
    var cookieHeader = handshake.headers.cookie;
    if (! cookieHeader) {
      return accept(null, false);  // No cookie containing session id
    }
    var cookies = cookie.parse(cookieHeader);
    var key = store._sessionKey;
    var secret = store._sessionSecret;
    var signedCookies = parseSignedCookies(cookies, store._sessionSecret);
    var unsignedCookie = signedCookies[key];
    if (!unsignedCookie) {
      // We can't re-use `cookies` because it was mutated in parseSignedCookies
      var rawCookie = cookie.parse(cookieHeader)[key];
      if (rawCookie) {
        unsignedCookie = parseSignedCookie(rawCookie, secret);
      } else {
        return accept(null, false);  // No cookie containing session id
      }
    }
    sessStore.load(unsignedCookie, function (err, session) {
      if (err || !session) {
        return accept(err, false); // Error retrieving session
      }
      handshake.session = session;
      accept(null, true);  // Authorized
    });
  });
}

/**
 * Add (and later remove) the socket to
 * Store#_socketsBySessionId[socket.session.id]
 *
 * @param {Store} store
 * @param {Socket} socket
 * @param {String} clientId
 */
function onSocketConnection (store, socket, clientId) {
  if (! socket.handshake.session) return; // Happens in tests with mock socketio
  var session = socket.session = socket.handshake.session
    , socketsBySessId = store._socketsBySessionId
    , sessionId = session.id
    , sockets = socketsBySessId[sessionId] || (socketsBySessId[sessionId] = []);


  if (~ sockets.indexOf(socket)) return;

  sockets.push(socket);
  socket.once('disconnect', function () {
    var pos = sockets.indexOf(socket);
    if (~pos) {
      sockets.splice(pos, 1);
      if (!sockets.length) delete socketsBySessId[sessionId];
    }
  });

  // TODO Clean this listeners up upon disconnection
//  socket.on('message', touchSession);
//  socket.on('anything', touchSession);
//
//  /**
//   * This should send minimal periodic headers['Set-Cookie'] updates down to
//   * the browser to update cookie.expiry. This can only be done in response to
//   * an http request. If the socket transport is http, then we use the response
//   * of the http request containing the socket.io payload. Otherwise, we tell
//   * the browser to use an empty XHR to automatically update the cookie expiry.
//   */
//  function touchSession () {
//    var session = socket.session;
//
//    // This should also periodically update the cookie expiry
//
//    session.touch();
//  }
}

// TODO We might want to consider refreshing the
// cookie holding the session every X seconds as long as messages are being
// received from the client.
// - Every time we receive a message, check to see
//   (expiry - window) <= now <= expiry
//   If so, then send a message to the browser to ask it to make an AJAX
//   request to refresh its cookie expiry. This will refresh the session
//   expiry, and doing so should be reflected everywhere the session exists.
//   Perhaps this would be easiest with a Session store that is a racer Model
//   or Store.

function patchSessionStore (sessStore, store, persistentStore) {
  // Re-wrap this._sessionStore.destroy, to also remove the session from
  // every associated socket when the session is destroyed
  var socketsBySessId = store._socketsBySessionId
    , oldSessDestroy = sessStore.destroy;

  sessStore.destroy = function (sid, fn) {
    var sockets = socketsBySessId[sid]

    if (persistentStore) {
      fn = finishAfter(2, fn);
    }
    for (var i = sockets.length; i--; ) {
      var socket = sockets[i]
      delete socket.session;
      var clientId = socket.handshake.query.clientId;
      store.reloadClient(clientId);
    }
    persistentStore.destroy(sid, fn);
    return oldSessDestroy.call(this, sid, fn);
  };

  sessStore.load = sessStore.get = function (sid, fn) {
    var self = this;
    process.nextTick(function(){
      var expires
        , sess = self.sessions[sid];
      if (sess) {
        expires = 'string' == typeof sess.cookie.expires
          ? new Date(sess.cookie.expires)
          : sess.cookie.expires;
        if (!expires || new Date < expires) {
          fn(null, sess);
        } else {
          self.destroy(sid, fn);
        }
      } else if (persistentStore){
        persistentStore.get(sid, fn);
      } else {
        fn();
      }
    });
  };

  sessStore.set = function (sid, sess, fn) {
    var self = this;
    process.nextTick(function(){
      self.sessions[sid] = sess;
      if (persistentStore) {
        persistentStore.set(sid, sess, fn);
      } else {
        fn && fn();
      }
    });
  };
}
