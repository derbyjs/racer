Model = require '../../lib/Model'
_ = require '../../lib/util'
mocks = require './mocks'

exports.newModel = (environment) ->
  _.onServer = environment == 'server'
  return new Model()
  
exports.mockSocketModel = (clientId = '', onMessage = ->) ->
  serverSocket = new mocks.ServerSocketMock()
  browserSocket = new mocks.BrowserSocketMock(serverSocket)
  serverSocket.on 'connection', (client) ->
    client.on 'message', (message) ->
      setTimeout (-> onMessage message), 0
  model = exports.newModel 'browser'
  model._clientId = clientId
  model._setSocket browserSocket
  return [serverSocket, model]