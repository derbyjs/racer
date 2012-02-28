Model = require '../../src/Model'
mocks = require './mocks'
transaction = require '../../src/transaction'
require 'console.color'

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
  newTxns = []
  serverSockets = new mocks.ServerSocketsMock()
  serverSockets._queue = (txn) ->
    transaction.base txn, ++ver
    newTxns.push txn
  serverSockets.on 'connection', (socket) ->
    socket.on 'txnsSince', (ver, clientStartId, callback) ->
      callback newTxns, ++num
      newTxns = []
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
  store = options.store || serverRacer.createStore options

  browserModels = []
  i = numWindows
  while i--
    serverModel = store.createModel()
    browserModel = new Model
    browserSocket = new mocks.BrowserSocketMock serverSockets
    do (serverModel, browserModel, browserSocket) ->
      serverModel.subscribe sandboxPath, (sandbox) ->
        serverModel.ref '_test', sandbox
        sandbox.setNull {}
        serverModel.bundle (bundle) ->
          bundle = JSON.parse(bundle)
          bundle.socket = browserSocket
          browserRacer.init.call model: browserModel, bundle
          browserSocket._connect()
          browserModels.push browserModel
          if browserModels.length == numWindows
            callback serverSockets, store, browserModels...

exports.fullSetup = (options, clients, done) ->
  serverSockets = new mocks.ServerSocketsMock()
  if store = options.store
    store.setSockets serverSockets
  else
    options.sockets = serverSockets
    store = serverRacer.createStore options

  browserModels = {}
  browserFns = {}
  serverFinishes = {}
  browserFinishes = {}
  remWindows = remServerModels = numWindows = Object.keys(clients).length

  timeout = options.timeout || 2000
  setTimeout ->
    if remWindows + remServerModels > 0
      console.red.log "\nThe following functions did not invoke finish within #{timeout} ms:\n"
      for cid of serverFinishes
        console.red.log clients[cid].server.toString() + "\n"
      for cid of browserFinishes
        console.red.log clients[cid].browser.toString() + "\n"
      return
  , timeout

  for clientId, {server, browser} of clients
    browserModels[clientId] = browserModel = new Model
    browserFns[clientId] = browser
    browserFinishes[clientId] = do (clientId) ->
      return ->
        delete browserFinishes[clientId]
        return if --remWindows
        serverSockets._disconnect()
        done()

    serverModel = store.createModel()
    serverFinish = serverFinishes[clientId] =
      do (clientId, serverModel, browserModel) ->
        return ->
          delete serverFinishes[clientId]
          serverModel.bundle (bundle) ->
            bundle = JSON.parse bundle
            bundle.socket = browserSocket = new mocks.BrowserSocketMock serverSockets
            browserRacer.init.call model: browserModel, bundle
            browserSocket._connect()
            return if --remServerModels
            for _clientId_, _browserModel_ of browserModels
              browserFns[_clientId_] _browserModel_, browserFinishes[_clientId_]
    server serverModel, serverFinish
  return
