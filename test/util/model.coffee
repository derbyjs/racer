{calls} = require './index'
{ServerSocketsMock, BrowserSocketMock} = require './sockets'
extended = [
  racerPath = require.resolve '../../src/racer'
  require.resolve '../../src/util'
  require.resolve '../../src/plugin'
  require.resolve '../../src/Model'
  require.resolve '../../src/transaction'
]
clearExtended = ->
  for path in extended
    delete require.cache[path]
  return

exports.createBrowserRacer = createBrowserRacer = ->
  # Delete the cache of all modules extended for the server
  clearExtended()
  # Pretend like we are in a browser and require again
  global.window = {}
  browserRacer = require racerPath
  # Reset state and delete the cache again, so that the next
  # time racer is required it will be for the server
  delete global.window
  clearExtended()
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
  model = new BrowserModel
  model._clientId = clientId
  model._setSocket browserSocket
  browserSocket._connect()  unless options.unconnected
  return [model, serverSockets]

# Create one or more browser models that are connected to a store over a
# mock Socket.IO connection
#
# options:
#   numBrowsers:  Number of browser models to create. Defaults to 1
#   calls:        Expected number of calls to the done() function
ns = 0
exports.mockFullSetup = (getStore, options, callback) ->
  if typeof options is 'function'
    callback = options
    options = {}
  options ||= {}
  numBrowsers = options.numBrowsers || 1
  numCalls = options.calls || 1
  serverSockets = new ServerSocketsMock()

  test = calls numCalls, (done) ->
    browserModels = []
    i = numBrowsers
    store = getStore()
    while i-- then do ->
      serverModel = store.createModel()
      serverModel.subscribe "tests.#{++ns}", (sandbox) ->
        serverModel.ref '_test', sandbox
        sandbox.del()
        serverModel.bundle (bundle) ->
          browserRacer = createBrowserRacer()
          browserSocket = new BrowserSocketMock serverSockets
          browserRacer.init JSON.parse(bundle), browserSocket
          browserSocket._connect()
          browserModels.push browserRacer.model
          --numBrowsers || callback browserModels..., done

  return (done) ->
    test done
    serverSockets._disconnect()
