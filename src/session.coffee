connect = require 'connect'
# TODO: Implement proper session security

module.exports = (store, options) ->
    # The actual middleware is created by a factory so that the store
    # can be set later
    fn = (req, res, next) ->
      throw 'Missing session middleware'  unless req.session
      fn = sessionFactory store
      fn req, res, next
    
    throw 'Session options argument is required' unless options
    # TODO: Add support for other kinds of session stores
    throw 'Unimplemented: Non-racer session stores are currently unsupported.' if options.store

    options.store = sessionStore = new SessionStore store
    connectSession = connect.session options
    middleware = (req, res, next) ->
      connectSession req, res, ->
        fn req, res, next
    middleware._setStore = (_store) ->
      sessionStore._setStore _store
      return store = _store
    return middleware

sessionFactory = (store) ->
  (req, res, next) ->
    # Make sure to use only the unsalted id in client side code
    sessionId = req.sessionID
    sessionId = sessionId.substr 0, sessionId.indexOf('.')
    
    model = req.model ||= store.createModel()
    model.subscribe _session: "$sessions.#{sessionId}.**", next


SessionStore = (@_racerStore) -> return

SessionStore:: =
  __proto__: connect.session.Store

  _setStore: (@_racerStore) ->

  get: (sid, callback) ->
    @_racerStore.get "$sessions.#{sid}", callback

  # SessionStore forces all mutation operations by supplying a null version
  set: (sid, value, callback) ->
    @_racerStore.set "$sesssions.#{sid}", value, null, callback

  destroy: (sid, callback) ->
    @_racerStore.del "$sessions.#{sid}", null, callback

  length: (callback) ->
    count = 0
    count++ for key of @_racerStore.get "$sessions"
    callback count

  clear: (callback) ->
    @_racerStore.del "$sessions", null, callback
