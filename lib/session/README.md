Sessions
========

## Session and Socket Lifecycle

### Session Creation

This section describes the lifecycle of a session and of a socket as it relates
to a session.

Sessions are initially established by express middleware (created via
Store#sessionMiddleware), upon the first http request by a client.

### Session/Socket Association

Once the client loads the page response from the first http request, socket.io
sends an AJAX handshake request.

During the handshake, racer loads the server session associated with the client
(established in the first request) using the handshake request headers. It
assigns this server session to the handshake data.

If the handshake is successful, then the client and server establish a
socket connection. The socket connection has a reference to the handshake
data and therefore has access to an assigned session.

A session can be associated with multiple sockets. This would be the case, for
instance, if several tabs in a browser window are connected to your app. Each
tab would have its own socket, but all sockets would share the same session
because they belong to the same browser.

After the creation of a socket between browser and server, any data received
by the server over the socket can be authorized by the socket using the
associated session.

### Socket Disconnection

When the socket disconnects, the socket should disable its association with
the session until the socket reconnects.

### Socket Destruction

When the socket is destroyed, the session should be removed from the socket.
If all sockets associated with a session are destroyed, ...

### Destroying/Expiring Sessions

When the session expires or is destroyed, the session should be removed from
every socket with which it was associated. What happens then if another
tab establishes a new session?
