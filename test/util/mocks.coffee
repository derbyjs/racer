util = require('util')
EventEmitter = require('events').EventEmitter

ServerSocketMock =
exports.ServerSocketMock = ->
  self = this
  clients = this._clients = []
  self.on 'connection', (client) ->
    clients.push client.browserSocket
    client._serverSocket = self
  self.broadcast = (message) ->
    clients.forEach (client) ->
      client.emit 'message', JSON.stringify message
  return
util.inherits ServerSocketMock, EventEmitter

ServerClientMock = (browserSocket) ->
  self = this
  self.browserSocket = browserSocket
  self.broadcast = (message) ->
    self._serverSocket._clients.forEach (client) ->
      if browserSocket != client
        client.emit 'message', JSON.stringify message
  return
util.inherits ServerClientMock, EventEmitter

BrowserSocketMock =
exports.BrowserSocketMock = (serverSocket) ->
  self = this
  serverClient = new ServerClientMock self
  self.connect = ->
    serverSocket.emit 'connection', serverClient
  self.send = (message) ->
    serverClient.emit 'message', JSON.stringify message
  return
util.inherits BrowserSocketMock, EventEmitter
