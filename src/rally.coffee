Model = require './Model'
modelServer = require './Model.server'
Store = require './Store'
transaction = require './transaction'
io = require 'socket.io'
browserify = require 'browserify'
fs = require 'fs'

# Add the server side functions to Model's prototype
Model::[name] = fn for name, fn of modelServer

# TODO: This solution only works for a single server. Fix to work with
# multiple servers
clientIdCount = 1
nextClientId = -> (clientIdCount++).toString(36)

ioUri = ''

module.exports = rally = (options) ->
  ioPort = options.ioPort || 80
  ioUri = options.ioUri || ':' + ioPort
  ioSockets = options.ioSockets || io.listen(ioPort).sockets
  
  ioSockets.on 'connection', (socket) ->
    socket.on 'txn', (txn) ->
      store._commit txn, (err, txn) ->
        return socket.emit 'txnFail', transaction.id txn if err
        socket.broadcast.emit 'txn', txn
        socket.emit 'txn', txn
  
  # The rally module returns connect middleware for
  # easy integration into connect/express
  return (req, res, next) ->
    if !req.session
      throw 'Missing session middleware'
    session = req.session
    session.clientId = clientId = session.clientId || nextClientId()
    req.model = new Model clientId, ioUri
    next()

rally.store = store = new Store
rally.subscribe = (path, callback) ->
  # TODO: Accept a list of paths
  # TODO: Attach to an existing model
  # TODO: Support path wildcards, references, and functions
  model = new Model nextClientId(), ioUri
  store.get path, (err, value, ver) ->
    callback err if err
    model._set path, value
    model._base = ver
    callback null, model
rally.unsubscribe = ->
  throw "Unimplemented"
rally.use = ->
  throw "Unimplemented"
rally.js = ->
  browserify.bundle(require: 'rally') + fs.readFileSync __dirname +
    '/../node_modules/socket.io/node_modules/socket.io-client/dist/socket.io.js'
