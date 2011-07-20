@model = model = new (require './Model')

@init = ({data, base, clientId, txnCount, ioUri}) ->
  model._adapter._data = data
  model._adapter.ver = base
  model._clientId = clientId
  model._txnCount = txnCount
  model._setSocket io.connect ioUri
  return this
