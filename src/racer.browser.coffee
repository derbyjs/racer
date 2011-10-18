require 'es5-shim'
util = require './util'
Model = require './Model'
Field = require './mixin.ot/Field'

if 'undefined' != typeof io # io will be undefined in tests - see test/util/model fullyWiredModels
  # Patch Socket.io-client to publish the close event and disconnet immediately
  io.Socket::onClose = ->
    @open = false
    @publish 'close'
    @onDisconnect()


isReady = false

racer = module.exports =

  model: new Model

  init: (options) ->
    model = @model
    
    incomingOtFields = options.otFields
    for path, json of incomingOtFields
      field = Field.fromJSON json, model
      model.otFields[path] = field

    model._adapter._data = world: options.data
    model._adapter._vers = ver: options.base
    model._clientId = options.clientId
    model._storeSubs = options.storeSubs
    model._startId = options.startId
    model._txnCount = options.txnCount
    model._onTxnNum options.txnNum
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
      model = @model
      connected = model.socket.socket.connected
      onready()
      # Republish the Socket.IO connect event after the onready callback
      # executes in case any client code wants to use it
      model.socket.socket.publish 'connect' if connected

  util: util
  Model: Model
