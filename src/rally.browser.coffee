require 'es5-shim'
@model = model = new (require './Model')

# Patch Socket.io-client to actually publish the close event
io.Socket::onClose = ->
  @open = false
  @publish 'close'
  @onDisconnect()

@init = ({data, base, clientId, txnCount, txnNum, ioUri}) ->
  model._adapter._data = data
  model._adapter.ver = base
  model._clientId = clientId
  model._txnCount = txnCount
  model._txnApplier._serializingIndex = txnNum + 1
  model._setSocket io.connect ioUri,
    'reconnection delay': 50
    'max reconnection attempts': 20
  @onload() if @onload
  return this
