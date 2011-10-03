Model = require 'Model'
mocks = require './mocks'
transaction = require '../../src/transaction'
  
exports.mockSocketModel = (clientId = '', name, onName = ->) ->
  serverSockets = new mocks.ServerSocketsMock()
  serverSockets.on 'connection', (socket) ->
    socket.on name, onName
  browserSocket = new mocks.BrowserSocketMock(serverSockets)
  model = new Model clientId
  model._setSocket browserSocket
  browserSocket._connect()
  return [serverSockets, model]

exports.mockSocketModels = (clientIds..., options = {}) ->
  if Object != options.constructor
    clientIds.push options
    options = txnOk: true
  serverSockets = new mocks.ServerSocketsMock
  serverSockets.on 'connection', (socket) ->
    socket.num = 1
    ver = 0
    txnNum = 1
    socket.on 'txn', (txn) ->
      transaction.base txn, ++ver
      if options.txnOk
        socket.emit 'txnOk', transaction.id(txn), transaction.base(txn), ++txnNum
        serverSockets.emit 'txn', txn, socket.num++
      else if err = options.txnErr
        socket.emit 'txnErr', err, transaction.id(txn)

  models = clientIds.map (clientId) ->
    model = new Model clientId
    browserSocket = new mocks.BrowserSocketMock serverSockets
    model._setSocket browserSocket
    browserSocket._connect()
    return model
  return [serverSockets, models...]


try
  browserRacer = require '../../src/racer.browser'
catch e
  throw e unless e.message == 'io is not defined'
serverRacer = require '../../src/racer'
nextNs = 1
exports.fullyWiredModels = (numWindows, callback) ->
  sandboxPath = "tests.#{nextNs++}"
  serverSockets = new mocks.ServerSocketMock
  store = serverRacer.createStore
    redis: {db: 2}
    sockets: serverSockets

  browserModels = []
  i = numWindows
  while i--
    browserModel = new Model
    console.log "!!"
    serverModel = store.createModel()
    store.subscribe _test: fullPath = "#{sandboxPath}.**", ->
      serverModel.setNull sandboxPath, {}
      serverModel.bundle (bundle) ->
        browserRacer.init.call browserModel, bundle
        browserModels.push browserModel
        if browserModels.length == numWindows
          callback serverSockets, browserModels...
