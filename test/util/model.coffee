Model = require '../../src/Model'
mocks = require './mocks'
transaction = require '../../src/transaction'
  
exports.mockSocketModel = (clientId = '', name, onName = ->) ->
  serverSockets = new mocks.ServerSocketsMock()
  serverSockets.on 'connection', (socket) ->
    socket.on name, onName
    socket.on 'txnsSince', (ver, clientStartId, callback) ->
      callback [], 1
  browserSocket = new mocks.BrowserSocketMock(serverSockets)
  model = new Model clientId
  model._setSocket browserSocket
  browserSocket._connect()
  return [model, serverSockets]

# Pass all transactions back to the client immediately
exports.mockSocketEcho = (clientId = '', unconnected) ->
  num = 0
  ver = 0
  serverSockets = new mocks.ServerSocketsMock()
  serverSockets.on 'connection', (socket) ->
    socket.on 'txnsSince', (ver, clientStartId, callback) ->
      callback [], ++num
    socket.on 'txn', (txn) ->
      socket.emit 'txnOk', transaction.id(txn), ++ver, ++num
  browserSocket = new mocks.BrowserSocketMock(serverSockets)
  model = new Model clientId
  model._setSocket browserSocket
  browserSocket._connect() unless unconnected
  return [model, serverSockets]

exports.mockSocketModels = (clientIds..., options = {}) ->
  if Object != options.constructor
    clientIds.push options
    options = txnOk: true
  serverSockets = new mocks.ServerSocketsMock
  serverSockets.on 'connection', (socket) ->
    socket.num = 1
    ver = 0
    txnNum = 1
    socket.on 'txnsSince', (ver, clientStartId, callback) ->
      callback [], socket.num
    socket.on 'txn', (txn) ->
      txn = JSON.parse JSON.stringify txn
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


browserRacer = require '../../src/racer.browser'
serverRacer = require '../../src/racer'
nextNs = 1
exports.fullyWiredModels = (numWindows, callback, options = {}) ->
  sandboxPath = "tests.#{nextNs++}"
  serverSockets = new mocks.ServerSocketsMock()
  options.sockets = serverSockets
  options.redis ||= redis: {db: 2}
  store = serverRacer.createStore options

  browserModels = []
  i = numWindows
  while i--
    serverModel = store.createModel()
    browserModel = new Model
    browserSocket = new mocks.BrowserSocketMock serverSockets
    do (serverModel, browserModel, browserSocket) ->
      serverModel.subscribe _test: sandboxPath, ->
        serverModel.setNull sandboxPath, {}
        serverModel.bundle (bundle) ->
          bundle = JSON.parse(bundle)
          bundle.socket = browserSocket
          browserRacer.init.call model: browserModel, bundle
          browserSocket._connect()
          browserModels.push browserModel
          if browserModels.length == numWindows
            callback serverSockets, store, browserModels...
