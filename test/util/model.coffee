Model = require 'Model'
mocks = require './mocks'
transaction = require '../../src/transaction'
  
exports.mockSocketModel = (clientId = '', name, onName = ->) ->
  serverSockets = new mocks.ServerSocketsMock()
  serverSockets.on 'connection', (socket) -> socket.on name, onName
  browserSocket = new mocks.BrowserSocketMock(serverSockets)
  model = new Model clientId
  model._setSocket browserSocket
  browserSocket._connect()
  return [serverSockets, model]

exports.mockSocketModels = (clientIds...) ->
  serverSockets = new mocks.ServerSocketsMock
  serverSockets.on 'connection', (socket) ->
    socket.num = 1
    ver = 0
    txnNum = 1
    socket.on 'txn', (txn) ->
      transaction.base txn, ++ver
      socket.emit 'txnOk', transaction.id(txn), transaction.base(txn), ++txnNum
      serverSockets.emit 'txn', txn, socket.num++

  models = clientIds.map (clientId) ->
    model = new Model clientId
    browserSocket = new mocks.BrowserSocketMock serverSockets
    model._setSocket browserSocket
    browserSocket._connect()
    return model
  return [serverSockets, models...]
