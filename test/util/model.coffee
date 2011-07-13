Model = require 'Model'
mocks = require './mocks'
  
exports.mockSocketModel = (clientId = '', name, onName = ->) ->
  serverSockets = new mocks.ServerSocketsMock()
  serverSockets.on 'connection', (socket) -> socket.on name, onName
  browserSocket = new mocks.BrowserSocketMock(serverSockets)
  model = new Model clientId
  model._setSocket browserSocket
  return [serverSockets, model]