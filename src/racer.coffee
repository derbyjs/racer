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

Store::listen = (to) ->
  io = socketio.listen to
  io.configure ->
    io.set 'browser client', false
    io.set 'transports', DEFAULT_TRANSPORTS
  socketUri = if typeof to is 'number' then ':' + to else ''
  @setSockets io.sockets, socketUri


module.exports =

  createStore: (options) ->
    # TODO: Provide full configuration for socket.io
    store = new Store options
    if options.sockets
      store.setSockets options.sockets, options.socketUri
    else if options.listen
      store.listen options.listen
    return store

  js: (options, callback) ->
    [callback, options] = [options, {}] if typeof options is 'function'
    require = ['racer']
    options.require = if options.require
        require.concat options.require
      else require
    if (minify = options.minify) is undefined then minify = true
    options.filter = uglify if minify
    
    ioClient.builder DEFAULT_TRANSPORTS, {minify}, (err, value) ->
      throw err if err
      callback value + ';' + browserify.bundle options

  ## Connect Middleware ##
  # The racer module returns connect middleware for
  # easy integration into connect/express
  # 1. Assigns clientId's if not yet assigned
  # 2. Instantiates a new Model and attaches it to the incoming request,
  #    for access from route handlers later
  middleware: (store) ->
    return (req, res, next) ->
      if !req.session
        # TODO Do this check only the first time the middleware is invoked
        throw 'Missing session middleware'
      finish = (clientId) ->
        req.model = new Model clientId
        next()
      # TODO Security checks via session
      if clientId = req.params.clientId || req.body.clientId
        finish clientId
      else
        store._nextClientId finish

  util: util

