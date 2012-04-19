# TODO: Implement proper session security

module.exports = (store) ->
    # The actual middleware is created by a factory so that the store
    # can be set later
    fn = (req, res, next) ->
      throw 'Missing session middleware'  unless req.session
      fn = sessionFactory store
      fn req, res, next

    middleware = (req, res, next) -> fn req, res, next
    middleware._setStore = (_store) -> store = _store
    return middleware

sessionFactory = (store) ->
  (req, res, next) ->
    # Make sure to use only the unsalted id in data exposed to the client
    sid = req.sessionID

    model = req.model ||= store.createModel()
    model.subscribe "sessions.#{sid}", (err, session) ->
      model.ref '_session', session
      next()
