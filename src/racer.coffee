Model = require './Model.server'
Store = require './Store'
socketio = require 'socket.io'
ioClient = require 'socket.io-client'
browserify = require 'browserify'
uglify = require 'uglify-js'
{isProduction} = util = require './util'
session = require './session'

DEFAULT_TRANSPORTS = ['websocket', 'xhr-polling']

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


racer = module.exports =

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
    if ({minify} = options) is undefined then minify = isProduction
    options.filter = uglify if minify

    ioClient.builder DEFAULT_TRANSPORTS, {minify}, (err, value) ->
      throw err if err
      callback value + ';' + browserify.bundle options

  util: util
  Model: Model

  # Returns Middleware adapter for Connect sessions
  session: session

Object.defineProperty racer, 'version',
  get: -> JSON.parse(fs.readFileSync __dirname + '/../package.json', 'utf8').version
