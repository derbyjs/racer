fs = require 'fs'
browserify = require 'browserify'
socketio = require 'socket.io'
socketioClient = require 'socket.io-client'
uglify = require 'uglify-js'

module.exports = (racer) ->
  {isProduction, mergeAll} = racer.util

  mergeAll racer,

    Model: require './Model.server'
    session: require './session'
    Store: Store = require './Store'
    transaction: require './transaction.server'

    transports: ['websocket', 'xhr-polling']

    adapters:
      journal: {}
      pubSub: {}
      db: {}
      clientId: {}

    createStore: (options = {}) ->
      # TODO: Provide full configuration for socket.io
      store = new Store options
      if options.sockets
        store.setSockets options.sockets, options.socketUri
      else if options.listen
        store.listen options.listen, options.namespace
      return store

    createAdapter: (adapterType, options) ->
      unless Adapter = racer.adapters[adapterType][options.type]
        throw new Error "No #{adapterType} adapter found for #{options.type}"
      return new Adapter options

    # Returns a string of javascript representing a browserify bundle
    # and the socket.io client-side code
    #
    # Options:
    #   Racer-specific:
    #     minify:  true/false
    #   Passed to browserify:
    #     entry:   e.g., __dirname + '/client.js'
    #     filter:  defaults to uglify if minify is true
    #     debug:   true unless in production
    js: (options, callback) ->
      if typeof options is 'function'
        callback = options
        options = {}
      {minify} = options
      minify = isProduction  unless minify?
      options.filter = uglify  if minify && !options.filter

      # Add pseudo filenames and line numbers in browser debugging
      options.debug = true  unless isProduction || options.debug?

      socketioClient.builder racer.transports, {minify}, (err, value) ->
        throw err if err
        callback value + ';' + browserify.bundle options

  Object.defineProperty racer, 'version',
    get: -> JSON.parse(fs.readFileSync __dirname + '/../package.json', 'utf8').version

  # TODO: Redis journal and pubsub should not be included by default once
  # the memory versions are written
  racer  
    .use(require 'racer-journal-redis')
    .use(require 'racer-pubsub-redis')
    .use(require './adapters/db-memory')
    .use(require './adapters/clientid-mongo')
    .use(require './adapters/clientid-redis')
    .use(require './adapters/clientid-rfc4122_v4')
