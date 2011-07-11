Model = require 'Model'
mocks = require './mocks'
  
exports.mockSocketModel = (clientId = '', onTxn = ->) ->
  serverSockets = new mocks.ServerSocketsMock()
  serverSockets.on 'connection', (socket) -> socket.on 'txn', onTxn
  browserSocket = new mocks.BrowserSocketMock(serverSockets)
  model = new Model()
  model._clientId = clientId
  model._setSocket browserSocket
  return [serverSockets, model]