{calls, changeEnvTo} = require './index'
{ServerSocketsMock, BrowserSocketMock} = require './sockets'

exports.createBrowserRacer = createBrowserRacer = (plugins) ->
  changeEnvTo 'browser'
  # Pretend like we are in a browser and require again
  browserRacer = require '../../lib/racer'
  browserRacer.setMaxListeners 0
  if plugins
    for plugin in plugins
      pluginOpts = plugin.testOpts
      browserRacer.use plugin, pluginOpts if plugin.useWith.browser
  changeEnvTo 'server'
  return browserRacer

exports.BrowserModel = BrowserModel = createBrowserRacer().Model
transaction = require '../../lib/transaction'


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
  browserSocket = new BrowserSocketMock serverSockets, clientId
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
    transaction.setVer txn, ++ver
    newTxns.push txn
  serverSockets.on 'connection', (socket) ->
    socket.on 'txnsSince', (ver, clientStartId, callback) ->
      callback null, newTxns, ++num
      newTxns = []
    socket.on 'txn', (txn) ->
      if err = options.txnErr
        socket.emit 'txnErr', err
      else
        socket.emit 'txnOk', transaction.getId(txn), ++ver, ++num
  browserSocket = new BrowserSocketMock(serverSockets, clientId)
  model = if plugins = options.plugins
    new (createBrowserRacer(options.plugins).Model)
  else
    new BrowserModel
  model._clientId = clientId
  model._setSocket browserSocket
  browserSocket._connect()  unless options.unconnected
  return [model, serverSockets]

exports.createBrowserModel = createBrowserModel = (store, testPath, plugins, callback) ->
  if typeof plugins is 'function'
    callback = plugins
    plugins = []
  plugins ||= []
  model = store.createModel()
  model.subscribe testPath, (err, sandbox) ->
    model.ref '_test', sandbox
    model.bundle (bundle) ->
      browserRacer = createBrowserRacer plugins
      browserSocket = new BrowserSocketMock store.sockets, model._clientId
      browserRacer.on 'ready', (model) ->
        browserSocket._connect()
        callback model
      browserRacer.init JSON.parse(bundle), browserSocket

# Create one or more browser models that are connected to a store over a
# mock Socket.IO connection
#
# plugins:      Racer plugins to include in browser instances
ns = 0
exports.mockFullSetup = (store, done, plugins, callback) ->
  if typeof plugins is 'function'
    callback = plugins
    plugins = []
  plugins ||= []
  numBrowsers = callback.length - 1 # subtract 1 for the done parameter
  serverSockets = new ServerSocketsMock()
  testPath = "tests.#{++ns}"

  allDone = (err) ->
    return done err if err
    serverSockets._disconnect()
    done()

  browserModels = []
  i = numBrowsers
  store.setSockets serverSockets
  while i--
    createBrowserModel store, testPath, plugins, (model) =>
      browserModels.push model
      --numBrowsers || callback browserModels..., allDone
