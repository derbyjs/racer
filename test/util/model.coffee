{calls, clearRequireCache} = require './index'
{ServerSocketsMock, BrowserSocketMock} = require './sockets'
racerPath = require.resolve '../../src/racer'

exports.createBrowserRacer = createBrowserRacer = (plugins) ->
  # Delete the cache of all modules extended for the server
  clearRequireCache()
  # Pretend like we are in a browser and require again
  global.window = {}
  browserRacer = require racerPath
  if plugins
    browserRacer.use plugin  for plugin in plugins
  # Reset state and delete the cache again, so that the next
  # time racer is required it will be for the server
  delete global.window
  clearRequireCache()
  return browserRacer

exports.BrowserModel = BrowserModel = createBrowserRacer().Model
{transaction} = require racerPath


# Create a model connected to a server sockets mock. Good for testing
# that models send expected commands over Socket.IO
#
# clientId:       The model's clientId
# name:           Name of browser-side socket event to handle
# onName:         Handler function for browser-side socket event
exports.mockSocketModel = (clientId = '', name, onName = ->) ->
  serverSockets = new ServerSocketsMock()
  serverSockets.on 'connection', (socket) ->
    socket.on name, onName
    socket.on 'txnsSince', (ver, clientStartId, callback) ->
      callback null, [], 1
  browserSocket = new BrowserSocketMock serverSockets
  model = new BrowserModel
  model._clientId = clientId
  model._setSocket browserSocket
  browserSocket._connect()
  return [model, serverSockets]

# Create a model connected to a server socket mock & pass all transactions
# back to the client immediately once received.
#
# clientId:       The model's clientId
# options:
#   unconnected:  Don't immediately connect the browser over the socket mock
#   txnErr:       Respond to transactions with a 'txnErr message' if true
#   plugins:      Racer plugins to include
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
  model = if plugins = options.plugins
    new (createBrowserRacer(plugins).Model)
  else
    new BrowserModel
  model._clientId = clientId
  model._setSocket browserSocket
  browserSocket._connect()  unless options.unconnected
  return [model, serverSockets]

exports.createBrowserModel = createBrowserModel = (store, testPath, options, callback) ->
  if typeof options is 'function'
    callback = options
    options = {}
  options ||= {}
  model = store.createModel()
  model.subscribe testPath, (err, sandbox) ->
    model.ref '_test', sandbox
    model.bundle (bundle) ->
      browserRacer = createBrowserRacer options.plugins
      browserSocket = new BrowserSocketMock store.sockets
      browserRacer.on 'ready', (model) ->
        browserSocket._connect()
        callback model
      browserRacer.init JSON.parse(bundle), browserSocket

# Create one or more browser models that are connected to a store over a
# mock Socket.IO connection
#
# options:
#   numBrowsers:  Number of browser models to create. Defaults to 1
#   calls:        Expected number of calls to the done() function
#   plugins:      Racer plugins to include in browser instances
ns = 0
exports.mockFullSetup = (getStore, options, callback) ->
  if typeof options is 'function'
    callback = options
    options = {}
  options ||= {}
  numBrowsers = options.numBrowsers || 1
  numCalls = options.calls || 1
  serverSockets = new ServerSocketsMock()
  testPath = "tests.#{++ns}"

  return calls numCalls, (done) ->
    allDone = (err) ->
      return done err if err
      serverSockets._disconnect()
      done()

    browserModels = []
    i = numBrowsers
    store = getStore()
    store.setSockets serverSockets
    while i--
      createBrowserModel store, testPath, options, (model) ->
        browserModels.push model
        --numBrowsers || callback browserModels..., allDone
