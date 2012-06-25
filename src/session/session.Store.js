var connect = require('connect')
  , parseCookie = connect.utils.parseCookie
  , createSessionMiddleware = connect.session
  , MemoryStore = createSessionMiddleware.MemoryStore;

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

  , socketio: setupSocketAuth

  , socket: onSocketConnection
  }

, proto: {
    /**
     * Returns a connect middleware function (req, res, next) that handles
     * session creation and management.
     *
     * @param {Object} opts
     * @return {Function} a connect middleware function
     * @api public
     */
    sessionMiddleware: function (opts) {
      opts || (opts = {});
      this._sessionKey = opts.key || (opts.key = 'connect.sid');
      var sessStore = this._sessionStore = opts.store;

      if (! sessStore) {
        sessStore = this._sessionStore = opts.store = new MemoryStore;
        // Re-wrap this._sessionStore.destroy, to also remove the session form
        // every associated socket when the session is destroyed
        var socketsBySessId = this._socketsBySessionId
          , oldSessDestroy = sessStore.destroy;
        sessStore.destroy = function (sid, fn) {
          var sockets = socketsBySessId[sid];
          for (var i = sockets.length; i--; ) {
            delete sockets[i].session;
          }
          return oldSessDestroy.call(sid, fn);
        };
      }

      return createSessionMiddleware(opts);
    }
  }
}

/**
 * Add additional handshake logic that converts the handshake request's cookie
 * into an express session. This session is assigned to the socket that can be
 * used to make decisions about how to process subsequent messages over the socket.
 *
 * @param {Store} store
 * @param {socketio.Manager} io
 * @api private
 */
function setupSocketAuth (store, io) {
  // Sets authorization callback for ALL socketio namespaces
  io.set('authorization', function (handshake, accept) {
    var sessionStore = this._sessionStore;
    if (! sessionStore) {
      return accept('No session store', false);
    }
    var cookieHeader = handshake.headers.cookie;
    if (! cookieHeader) {
      return accept('No cookie containing session id', false);
    }
    var cookie = parseCookie(cookieHeader);
    var sessionId = cookie[store._sessionKey].split('.')[0];
    sessionStore.load(sessionId, function (err, session) {
      if (err || !session) {
        return accept('Error retrieving session', false);
      }
      handshake.session = session;
      accept(null, true);
    });
  });
}

/**
 * Add (and later remove) the socket to
 * Store#socketsBySessionId[socket.session.id]
 *
 * @param {Store} store
 * @param {Socket} socket
 * @param {String} clientId
 */
function onSocketConnection (store, socket, clientId) {
  var session = socket.session = socket.handshake.session
    , socketsBySessionId = store._socketsBySessionId
    , sessionId = session.id
    , sockets = socketsBySessionId[sessionId] || (socketsBySessionId[sessionId] = []);

  if (~ sockets.indexOf(socket)) return;

  sockets.push(socket);
  socket.once('disconnect', function () {
    var pos = sockets.indexOf(socket);
    if (~pos) {
      sockets.splice(pos, 1);
      if (!sockets.length) delete socketsBySessionId[sessionId];
    }
  });
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
