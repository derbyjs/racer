var connect = require('connect')
  , Cookie = require('connect/lib/middleware/session/cookie')
  , parseSignedCookies = connect.utils.parseSignedCookies
  , parseSignedCookie = connect.utils.parseSignedCookie
  , createSessionMiddleware = connect.session
  , MemoryStore = createSessionMiddleware.MemoryStore
  , cookie = require('cookie')
  , finishAfter = require('../util/async').finishAfter
  ;

/**
 * The following is a description of the lifecycle of a session and of a socket
 * as it relates to a session.
 *
 * Sessions are initially established by express middleware (created via
 * Store#sessionMiddleware), upon the first http request by a client.
 *
 * Once the client loads the page response from the first http request,
 * socket.io sends an AJAX handshake request.
 *
 * During the handshake, racer loads the associated client-server session
 * (established in the first request) using the handshake request headers. It
 * assigns this server session to the handshake data.
 *
 * If the handshake is successful, then the client and server establish a
 * socket connection. The socket connection has a reference to the handshake
 * data and therefore has access to an assigned session. A session can be
 * associated with multiple sockets. This would be the case, for instance, if
 * several tabs in a browser window are connected to your app. Each tab would
 * have its own socket, but all sockets would share the same session because
 * they belong to the same browser.
 *
 * After the creation of a socket between browser and server, any data received
 * by the server over the socket can be authorized by the socket using the
 * associated session.
 *
 * When the socket disconnects, the socket should disable its association with
 * the session until the socket reconnects.
 *
 * When the socket is destroyed, the session should be removed from the socket.
 * If all sockets associated with a session are destroyed, ...
 *
 * When the session expires or is destroyed, the session should be removed from
 * every socket with which it was associated. What happens then if another
 * tab establishes a new session?
 */
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

  var securePairs = this._securePairs = {}
    , store = this;
  this.on('createRequestModel', function (req, model) {
    securePairs[model._clientId] = req.sessionID;
    var session = model.session = req.session
      , userId = session.userId || session.auth && session.auth.userId;
    if (userId) model.set('_userId', userId);
  });

  return createSessionMiddleware(opts);
}

/**
 * Returns a connect middleware function(req, res, next) that adds a getModel
 * method to each req. Note that getModel must return the same model if called
 * multiple times for the same request and the same store.
 *
 * @return {Function} a connect middleware function
 * @api public
 */
function modelMiddleware() {
  var store = this;
  function getModel() {
    var model = this._racerModel;
    if (model && model.store === store) {
      return model;
    }
    model = this._racerModel = store.createModel();
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
    var sessionId = unsignedCookie
      , clientId = handshake.query.clientId;
    if (store._securePairs[clientId] !== sessionId) {
      return accept(null, false);  // Unauthorized access
    }
    sessStore.load(sessionId, function (err, session) {
      if (err || !session) {
        return accept('Error retrieving session', false);
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
      delete store._securePairs[clientId];
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
      , securePairs = store._securePairs;

    if (persistentStore) {
      fn = finishAfter(2, fn);
    }
    for (var i = sockets.length; i--; ) {
      var socket = sockets[i]
      delete socket.session;
      var clientId = socket.handshake.query.clientId;
      delete securePairs[clientId];
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
