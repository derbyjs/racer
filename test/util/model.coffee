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

exports.BrowserModel = BrowserModel = createBrowserRacer().protected.Model
transaction = require '../../lib/transaction'


# Create a model connected to a server sockets mock. Good for testing
# that models send expected commands over Socket.IO
#
# clientId:       The model's clientId
# name:           Name of browser-side socket event to handle
# onName:         Handler function for browser-side socket event
exports.mockSocketModel = (clientId = '', name, onName = ->) ->
  serverSockets = new ServerSocketsMock
  serverSockets.on 'connection', (socket) ->
    return unless name
    return unless socket._browserSocket._clientId == clientId
    socket.on name, onName
  browserSocket = new BrowserSocketMock serverSockets, clientId
  model = new BrowserModel
  model._clientId = clientId
  model._setSocket browserSocket
  browserSocket.socket.connect()
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
  num = 0 # The client txn serializing number
  ver = 0
  newTxns = []
  serverSockets = new ServerSocketsMock
  serverSockets.on 'connection', (socket) ->
    socket.on 'txn', (txn) ->
      if err = options.txnErr
        socket.emit 'txnErr', err
      else
        transaction.setVer txn, ++ver
        socket.emit 'txnOk', txn, ++num
  browserSocket = new BrowserSocketMock(serverSockets, clientId)
  model = if plugins = options.plugins
    new (createBrowserRacer(options.plugins).protected.Model)
  else
    new BrowserModel
  model._clientId = clientId
  model._setSocket browserSocket
  browserSocket.socket.connect()  unless options.unconnected
  return [model, serverSockets]

exports.createBrowserModel = createBrowserModel = (store, testPath, plugins, callback) ->
  if typeof plugins is 'function'
    callback = plugins
    plugins = []
  if typeof callback is 'object'
    {preBundle, postBundle, preConnect, postConnect: callback} = callback
  plugins ||= []
  serverModel = store.createModel()
  serverModel.subscribe testPath, (err, sandbox) ->
    serverModel.ref '_test', sandbox
    preBundle?(serverModel)
    serverModel.bundle (bundle) ->
      setupBrowser = ->
        browserRacer = createBrowserRacer plugins
        browserSocket = new BrowserSocketMock store.sockets, serverModel._clientId
        browserRacer.on 'ready', (browserModel) ->
          preConnect?(browserModel)
          browserSocket.socket.connect()
          process.nextTick ->
            callback browserModel
        browserRacer.init JSON.parse(bundle), browserSocket
      if postBundle
        if postBundle.length == 1
          postBundle serverModel
          setupBrowser()
        else
          postBundle serverModel, setupBrowser
      else
        setupBrowser()

# Create one or more browser models that are connected to a store over a
# mock Socket.IO connection
#
# plugins:      Racer plugins to include in browser instances
ns = 0
exports.mockFullSetup = (store, done, plugins, callback) ->
  if typeof plugins is 'function'
    callback = plugins
    plugins = []
  if typeof callback is 'object'
    {postBundle, preBundle, preConnect, postConnect: callback} = callback
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
    createBrowserModel store, testPath, plugins,
      preBundle: preBundle
      postBundle: postBundle
      preConnect: preConnect
      postConnect: (model) ->
        browserModels.push model
        --numBrowsers || callback browserModels..., allDone
