require 'es5-shim'
util = require './util'
Model = require './Model'

# Patch Socket.io-client to publish the close event and disconnet immediately
io.Socket::onClose = ->
  @open = false
  @publish 'close'
  @onDisconnect()


isReady = false

racer = module.exports =

  model: model = new Model

  init: (options) ->
    model._adapter._data = options.data
    model._adapter.ver = options.base
    model._clientId = options.clientId
    model._storeSubs = options.storeSubs
    model._startId = options.startId
    model._txnCount = options.txnCount
    model._onTxnNum options.txnNum
    model._setSocket io.connect options.ioUri,
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

