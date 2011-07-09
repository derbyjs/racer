_ = require './util'
Model = require './Model'
modelServer = require './Model.server'
Store = require './Store'
io = require 'socket.io'

# Add the server side functions to Model's prototype
for name, fn of modelServer
  Model::[name] = fn

# rally itself is connect middleware, for
# easy integration into connect/express
if _.onServer
  rally = (req, res, next) ->
    if !req.session
      throw 'Missing session middleware'
    oldProto = rally.__proto__
    # re-define rally here, so we only do the
    # session middleware check once
    rally = (req, res, next) ->
      reqRally = req.rally = Object.create rally
      reqRally.clientId = req.session.clientId ||= rally.nextClientId++
      next()
    rally.__proto__ = oldProto
    rally req, res, next
  rally.nextClientId = 1
else
  rally = {}

module.exports = rally

methods =
  store: store = new Store
  subscribe: (path, callback) ->
    # TODO: Accept a list of paths
    # TODO: Attach to an existing model
    # TODO: Support path wildcards, references, and functions
    model = new Model
    store.get path, (err, value, ver) ->
      callback err if err
      model._set path, value
      model._base = ver
      callback null, model
  unsubscribe: ->
    throw "Unimplemented"
  use: ->
    throw "Unimplemented"

rally[name] = fn for name, fn of methods

io = io.listen 3001
io.sockets.on 'connection', (socket) ->
  socket.on 'txn', (data) ->
    # TODO: Actually submit transaction to STM instead of just echoing
    socket.emit 'txn', data
