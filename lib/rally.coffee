# Server-side rally definition

Model = require './Model'

rally = module.exports =
  model: new Model
  # Or we can place #store in Model::
  store: (adapter, config) ->
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
  html: ->
    # TODO
    throw "Unimplemented"

# Setters are nice because all you need to do is:
#
#     rally.app = app
#     rally.socket = socket
Object.defineProperty rally, 'app',
  get: () -> @app
  set: (app) ->
    addMiddleware app if isExpress app
    socketPromise.callback => @socket.listen app
    @app = app

Object.defineProperty rally, 'socket',
  get: () -> @model.socket
  set: (socket) ->
    socketPromise.fulfill socket
    @model.socket = socket

socketPromise = new Promise
