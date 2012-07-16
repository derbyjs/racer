Access Control
===============

# Overview

An app can define access control for:

- Reads (method x target type)
  - Methods: subscribe, fetch, reconnect state syncing
  - Target Types:
    - Paths and patterns
    - Queries
- Writes ({set, push, ...} x {path, path pattern})

## First Step - Turn Access Control On

By default, everything is allowed in a starter project. This makes it easier to
experiment with your app early on. When you are ready to turn security on, then
do the following:

```javascript
store = racer.createStore();
store.accessControl = true; // false by default
```

Turning this on blocks read and write access to everything. To enable access to
your reads and writes, you will need to whitelist access control using the
following APIs.

## Protecting Queries

Racer provides a means to protect both fetching and subscribing to a query:

```javascript
// On the server

// First, expose a query motif
store.query.expose('users', 'withRole', function (role) {
  return this.where('roles').contains([role]);
});

store.queryAccess('users', 'withRole', function (role, accept) {
  // Every Store#queryAccess callback has access to the session of the client
  // attempting to fetch the query motif "withRole" over the "users"
  // namespace.
  var session = this.session;

  // Access is allowed or rejected with the `accept` callback.
  // Passing `true` to `accept` passes control to the part of racer that does
  // the actual fetching of the query.
  // Passing `false` disables a read and sends an 'Unauthorized' error back to
  // the client over socket.io
  accept(~session.roles.indexOf('admin'));
});
```

This protects both calls to `model.subscribe(query, callback)` and
`model.fetch(query, callback)`.

## Protecting Reading Paths

Proctecting reading the value at a path (or paths defined by a path pattern) is
achieved in a similar manner as protecting queries:

```javascript
store.readPathAccess('users.*', function (pathFragment, accept) {
  var session = this.session;
  accept(session.isMember);
});
```

## Protecting Writes

Protecting writes are similar to protecting path reads, except you also need to
specify the mutator method.

```javascript
// Only let users set their own passwords
store.writeAccess('set', 'users.*.password', function (userId, accept) {
  var allowed = (userId === this.session.userId);
  accept(allowed);
});
```

You can use "*" to enable any kind of write (i.e., "set", "del", etc.) on a
path or path pattern:

```javascript
// Only let users set, delete, push, pop, etc against the list of their cars
store.writeAccess('*', 'users.*.cars', function (userId, accept) {
  var allowed = (userId === this.session.userId);
  accept(allowed);
});
```

## Other Security Considerations

There are various other security considerations that emerge in a framework such
as Derby/Racer. Here are a few of these other security issues and how Racer
guards against them.

### Protecting Model ClientId Hi-jacking

More info coming soon.

## Future Ideas

### Contexts

Contexts will provide a means to define different access control rules
depending on the scenario.

```javascript
store.context('admin', function () {
  store.queryAccess('users', 'withRole', function (role) {
    // Every Store#queryAccess callback has access to the session of the client
    // attempting to fetch the query motif "withRole" over the "users"
    // namespace.
    var session = this.session;

    // Returning true allows the read by passing control to the part of racer
    // that does the actual fetching of the query.
    // Returning false disables a read and sends a message back to the client
    // over socket.io.
    return ~session.roles.indexOf('admin');
  });
});
```

# Prior Brainstorming Notes

## Sessions

Sessions might be:

- Scoped Models
- A connect/express session

### Option 1: The Session as a Live Scoped Model

A racer-auth plugin could be implemented like:

```coffee
session._root.subscribe "users.#{userId}", (err, user) ->
  session.ref '_user', user
```

Advantages:

- The session is realtime, all the time.

Disadvantages:

- Deviates from the express session interface.

### Option 2: A connect/express session

A racer-auth plugin could be implemented like:

```coffee
model.subscribe "users.#{userId}", (err, user) ->
  model.on 'mutate', "users.#{userId}", (err, user) ->
    session.user = user.get()
```

The advantages:

- Does not deviate from the express session interface

The dis-advantages:

- If you set things directly on session, those changes will not propagate to
  other sockets with an equivalent session (unless we use sticky sessions; but
  even in this case, the changes will not propagate back to the original user
  object; unless the user object is a scoped model to the user object)

