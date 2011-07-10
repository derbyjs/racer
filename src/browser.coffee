@model = model = new (require './Model')

@init = ({data, base, clientId, txnCount, ioUri}) ->
  model._data = data
  model._base = base
  model._clientId = clientId
  model._txnCount = txnCount
  model._setSocket io.connect ioUri
  return this