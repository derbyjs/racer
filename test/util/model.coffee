Model = require 'Model'
mocks = require './mocks'

exports.newModel = (environment) ->
  return new Model()
  
exports.mockSocketModel = (clientId = '', onMessage = ->) ->
  serverSocket = new mocks.ServerSocketMock()
  browserSocket = new mocks.BrowserSocketMock(serverSocket)
  serverSocket.on 'connection', (client) ->
    client.on 'message', (message) ->
      setTimeout (-> onMessage JSON.parse message), 0
  model = exports.newModel 'browser'
  model._clientId = clientId
  model._setSocket browserSocket
  return [serverSocket, model]