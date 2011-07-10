Model = require './Model'
modelServer = require './Model.server'
Store = require './Store'
transaction = require './transaction'
io = require 'socket.io'
browserify = require 'browserify'
fs = require 'fs'

ioUri = ''
module.exports = rally = (options) ->
  # TODO: Provide full configuration for socket.io
  # TODO: Add configuration for Redis
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
    finish = (clientId) ->
      req.model = new Model clientId, ioUri
      next()
    if clientId = req.session.clientId
      finish clientId
    else
      nextClientId (clientId) ->
        req.session.clientId = clientId
        finish clientId

rally.store = store = new Store
rally.subscribe = (path, callback) ->
  # TODO: Accept a list of paths
  # TODO: Attach to an existing model
  # TODO: Support path wildcards, references, and functions
  nextClientId (clientId) ->
    model = new Model clientId, ioUri
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

# Add the server side functions to Model's prototype
Model::[name] = fn for name, fn of modelServer

stm = store._stm
nextClientId = (callback) -> stm._client.incr 'clientIdCount', (err, value) ->
  throw err if err
  callback value.toString(36)
