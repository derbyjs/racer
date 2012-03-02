{Model, transaction} = require '../../src/racer'
{ServerSocketsMock, BrowserSocketMock} = require './sockets'
require 'console.color'

exports.mockSocketModel = (clientId = '', name, onName = ->) ->
  serverSockets = new ServerSocketsMock()
  serverSockets.on 'connection', (socket) ->
    socket.on name, onName
    socket.on 'txnsSince', (ver, clientStartId, callback) ->
      callback null, [], 1
  browserSocket = new BrowserSocketMock serverSockets
  model = new Model
  model._clientId = clientId
  model._setSocket browserSocket
  browserSocket._connect()
  return [model, serverSockets]

# Pass all transactions back to the client immediately
exports.mockSocketEcho = (clientId = '', options = {}) ->
  num = 0
  ver = 0
  newTxns = []
  serverSockets = new ServerSocketsMock()
  serverSockets._queue = (txn) ->
    transaction.base txn, ++ver
    newTxns.push txn
  serverSockets.on 'connection', (socket) ->
    socket.on 'txnsSince', (ver, clientStartId, callback) ->
      callback null, newTxns, ++num
      newTxns = []
    socket.on 'txn', (txn) ->
      if err = options.txnErr
        socket.emit 'txnErr', err
      else
        socket.emit 'txnOk', transaction.id(txn), ++ver, ++num
  browserSocket = new BrowserSocketMock(serverSockets)
  model = new Model
  model._clientId = clientId
  model._setSocket browserSocket
  browserSocket._connect()  unless options.unconnected
  return [model, serverSockets]


browserRacer = require '../../src/racer.browser'
serverRacer = require '../../src/racer'
nextNs = 1
exports.fullyWiredModels = (numWindows, callback, options = {}) ->
  sandboxPath = "tests.#{nextNs++}"
  serverSockets = new ServerSocketsMock()
  options.sockets = serverSockets
  store = options.store || serverRacer.createStore options

  browserModels = []
  i = numWindows
  while i--
    serverModel = store.createModel()
    browserModel = new Model
    browserSocket = new BrowserSocketMock serverSockets
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
  serverSockets = new ServerSocketsMock()
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
    browserModel._clientId = clientId
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
            bundle.socket = browserSocket = new BrowserSocketMock serverSockets
            browserRacer.init.call model: browserModel, bundle
            browserSocket._connect()
            return if --remServerModels
            for _clientId_, _browserModel_ of browserModels
              browserFns[_clientId_] _browserModel_, browserFinishes[_clientId_]
    server serverModel, serverFinish
  return
