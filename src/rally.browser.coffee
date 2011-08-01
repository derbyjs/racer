require 'es5-shim'
@model = model = new (require './Model')

# Patch Socket.io-client to actually publish the close event
io.Socket::onClose = ->
  @open = false
  @publish 'close'
  @onDisconnect()

@init = (options) ->
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
  @onload() if @onload
  return this
