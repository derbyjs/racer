fs = require 'fs'
browserify = require 'browserify'
socketio = require 'socket.io'
socketioClient = require 'socket.io-client'
uglify = require 'uglify-js'
{registerAdapter} = require './adapters'
{isProduction} = require './util'

module.exports = (racer) ->
  racer.settings =
    env: process.env.NODE_ENV || 'development'

  racer.configure = (envs..., fn) ->
    fn.call this if envs[0] == 'all' || ~envs.indexOf @settings.env

  racer.set = (setting, value) ->
    @settings[setting] = value
    return this

  racer.get = (setting) -> @settings[setting]

  racer.set 'transports', ['websocket', 'xhr-polling']

  racer.configure 'production', ->
    @set 'minify', true

  racer.merge

    session: require './session'
    Store: Store = require './Store'

    createStore: (options = {}) ->
      # TODO: Provide full configuration for socket.io
      store = new Store options
      if sockets = options.sockets
        store.setSockets sockets, options.socketUri
      else if listen = options.listen
        store.listen listen, options.namespace
      return store

    registerAdapter: (type, name, AdapterKlass) ->
      registerAdapter type, name, AdapterKlass

    # Returns a string of javascript representing a browserify bundle
    # and the socket.io client-side code
    #
    # Options:
    #   minify: Set to truthy to minify the javascript
    #
    #   Passed to browserify:
    #     entry:   e.g., __dirname + '/client.js'
    #     filter:  defaults to uglify if minify is true
    #     debug:   true unless in production
    js: (options, callback) ->
      if typeof options is 'function'
        callback = options
        options = {}
      minify = options.minify || @get 'minify'
      options.filter = (@get('minifyFilter') || uglify) if minify && !options.filter

      # Add pseudo filenames and line numbers in browser debugging
      options.debug = true  unless isProduction || options.debug?

      socketioClient.builder racer.get('transports'), {minify}, (err, value) ->
        callback err, value + ';' + browserify.bundle options

  Object.defineProperty racer, 'version',
    get: -> JSON.parse(fs.readFileSync __dirname + '/../package.json', 'utf8').version

  racer
    .use(require './bundle.Model')  
    .use(require './adapters/journal-memory')
    .use(require './adapters/journal-none')
    .use(require './adapters/pubsub-memory')
    .use(require './adapters/pubsub-none')
    .use(require './adapters/db-memory')
    .use(require './adapters/clientid-mongo')
    .use(require './adapters/clientid-redis')
    .use(require './adapters/clientid-rfc4122_v4')
