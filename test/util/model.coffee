Model = require '../../lib/Model'
_ = require '../../lib/util'
mocks = require './mocks'

exports.newModel = (environment) ->
  _.onServer = environment == 'server'
  return new Model()
  
exports.mockSocketModel = (clientId = '', onConnection = -> {}) ->
  serverSocket = new mocks.ServerSocketMock()
  browserSocket = new mocks.BrowserSocketMock(serverSocket)
  serverSocket.on 'connection', onConnection
  model = exports.newModel 'browser'
  model._clientId = clientId
  model._setSocket browserSocket
  return [serverSocket, model]