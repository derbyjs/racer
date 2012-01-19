require 'es5-shim'
util = require './util'
Model = require './Model'
Field = require './mixin.ot/Field'

# isReady and model are used by the ready function, so that it can be called
# anonymously. This assumes that only one instace of Racer is running, which
# should be the case in the browser.
isReady = false
model = null

racer = module.exports =

  model: new Model

  init: (options) ->
    model = @model

    incomingOtFields = options.otFields
    for path, json of incomingOtFields
      field = Field.fromJSON json, model
      model.otFields[path] = field

    model._adapter._data = world: options.data
    model._adapter.version = options.base
    model._clientId = options.clientId
    model._storeSubs = options.storeSubs
    model._startId = options.startId
    model._count = options.count
    for [method, args] in options.onLoad
      model[method] args...
    model.emit 'initialized'
    # options.socket makes it easier to test - see text/util/model fullyWiredModels
    model._setSocket options.socket || io.connect options.ioUri,
      'reconnection delay': 50
      'max reconnection attempts': 20
    isReady = true
    racer.onready()
    return racer
  
  onready: ->
  ready: (onready) -> ->
    racer.onready = onready
    if isReady
      connected = model.socket.socket.connected
      onready()
      # Republish the Socket.IO connect event after the onready callback
      # executes in case any client code wants to use it
      model.socket.socket.publish 'connect' if connected

  util: util
  Model: Model
