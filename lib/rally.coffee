# Server-side rally definition
Model = require './Model'
store = require './store'

rally = module.exports =
  store: store
  subscribe: () ->
    throw "Unimplemented"
  use: () ->
    throw "Unimplemented"


(adapter, config) ->
  throw "Unimplemented"

  if init = config.init
    self = this

    # Before doneCb is invoked, nothing can interact
    # with the datastore beside the calls to model from
    # within the init code.
    # After doneCb is invoked, the store can receive
    # messages from other contexts (besides the init context)
    # TODO
    doneCb = (err) ->
      # TODO Replace throw with rally errorHandler
      throw err if err
      cmd.exec() for cmd in self.queuedStoreCommands
    config.init doneCb

# Setters are nice because all you need to do is:
#
#     rally.app = app
#     rally.socketio = io
#
# Alternatives:
#     rally.listen app
#     // or
#     rally.listen socketio
Object.defineProperty rally, 'app',
  get: () -> @app
  set: (app) ->
    addMiddleware app if isExpress app
    socketPromise.callback => @socket.listen app
    @app = app

Object.defineProperty rally, 'socketio',
  get: () -> @model.socketio
  set: (io) ->
    socketPromise.fulfill io
    @model.socketio = io

socketPromise = new Promise
