fs = require 'fs'
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
  version: JSON.parse(fs.readFileSync __dirname + '/../package.json', 'utf8').version

  createStore: (options) ->
    # TODO: Provide full configuration for socket.io
    store = new Store options
    if options.sockets
      store.setSockets options.sockets, options.socketUri
    else if options.listen
      store.listen options.listen, options.namespace
    return store

  # Returns a string of javascript representing a browserify bundle
  # of the racer client-side code and the socket.io client-side code
  # as well as any additional browserify options.
  #
  # Method signature 1:
  #   racer.js(callback)
  #
  # Method signature 2:
  #   racer.js(options, callback)
  #
  #   Options include:
  #   Options passed to browserify:
  #   - require: e.g., __dirname + '/shared'
  #   - entry:   e.g., __dirname + '/client.js'
  #   - filter: defaults to uglify if minify is true
  #   Racer-specific options:
  #   - minify: true/false
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
