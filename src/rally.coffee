Model = require './Model'
Store = require './Store'
transaction = require './transaction'
io = require 'socket.io'
browserify = require 'browserify'
fs = require 'fs'

ioUri = ''
ioSockets = null
module.exports = rally = (options) ->
  # TODO: Provide full configuration for socket.io
  # TODO: Add configuration for Redis

  ## Setup socket.io ##
  ioPort = options.ioPort || 80
  ioUri = options.ioUri || ':' + ioPort
  ioSockets = options.ioSockets || io.listen(ioPort).sockets
  ioSockets.on 'connection', (socket) ->
    socket.on 'txn', (txn) ->
      store.commit txn, (err, txn) ->
        return socket.emit 'txnFail', transaction.id txn if err
        ioSockets.emit 'txn', txn
  
  ## Connect Middleware ##
  # The rally module returns connect middleware for
  # easy integration into connect/express
  # 1. Assigns clientId's if not yet assigned
  # 2. Instantiates a new Model and attaches it to the incoming request,
  #    for access from route handlers later
  return (req, res, next) ->
    if !req.session
      # TODO Do this check only the first time the middleware is invoked
      throw 'Missing session middleware'
    finish = (clientId) ->
      req.model = new Model clientId, ioUri
      next()
    # TODO Security checks via session
    if clientId = req.params.clientId || req.body.clientId
      finish clientId
    else
      nextClientId (clientId) ->
        # TODO Ensure that the eventual response includes parameters to set
        #      the clientId in the browser window context
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

nextClientId = (callback) ->
  store._stm._client.incr 'clientIdCount', (err, value) ->
    throw err if err
    callback value.toString(36)

# Update Model's prototype to provide server-side functionality
Model::_send = (txn) ->
  onTxn = @_onTxn
  removeTxn = @_removeTxn
  store.commit txn, (err, txn) ->
    return removeTxn transaction.id txn if err
    onTxn txn
    ioSockets.emit 'txn', txn
  return true
Model::json = modelJson = (callback, self = this) ->
  setTimeout modelJson, 10, callback, self if self._txnQueue.length
  callback JSON.stringify
    data: self._data
    base: self._base
    clientId: self._clientId
    txnCount: self._txnCount
    ioUri: self._ioUri
