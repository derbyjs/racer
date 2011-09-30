Model = require './Model.server'
Store = require './Store'
socketio = require 'socket.io'
ioClient = require 'socket.io-client'
browserify = require 'browserify'
uglify = require 'uglify-js'
util = require './util'

DEFAULT_TRANSPORTS = ['websocket', 'xhr-polling']

Store::setSockets = (@sockets, ioUri = '') ->
  @_setSockets @sockets
  @_ioUri = ioUri

Store::listen = (to, namespace) ->
  io = socketio.listen to
  io.configure ->
    io.set 'browser client', false
    io.set 'transports', DEFAULT_TRANSPORTS
  io.configure 'production', ->
    io.set 'log level', 1
  socketUri = if typeof to is 'number' then ':' + to else ''
  if namespace
    @setSockets io.of("/#{namespace}"), "#{socketUri}/#{namespace}"
  else
    @setSockets io.sockets, socketUri


module.exports =

  createStore: (options) ->
    # TODO: Provide full configuration for socket.io
    store = new Store options
    if options.sockets
      store.setSockets options.sockets, options.socketUri
    else if options.listen
      store.listen options.listen, options.namespace
    return store

  js: (options, callback) ->
    [callback, options] = [options, {}] if typeof options is 'function'
    if (minify = options.minify) is undefined then minify = true
    options.filter = uglify if minify

    ioClient.builder DEFAULT_TRANSPORTS, {minify}, (err, value) ->
      throw err if err
      callback value + ';' + browserify.bundle options

  util: util

  # Middleware adapter for Connect sessions
  session: (store) ->
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
  # TODO Security checks
  (req, res, next) ->
    # Convert sessionID to path safe characters
    sessionId = req.sessionID.replace /[\.+//]/g, (s) -> switch s
      when '.' then ','
      when '+' then '-'
      when '/' then '_'
    model = req.model ||= store.createModel()
    model.subscribe _session: "sessions.#{sessionId}.**", next
