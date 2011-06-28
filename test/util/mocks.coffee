util = require('util')
EventEmitter = require('events').EventEmitter

ServerSocketMock =
exports.ServerSocketMock = ->
  EventEmitter.call this
  @clients = this._clients = []
  @on 'connection', (client) =>
    @clients.push client.browserSocket
    client._serverSocket = this
  return
ServerSocketMock.prototype =
  broadcast: (message) ->
    for client in @clients
      client.emit 'message', JSON.stringify message
ServerSocketMock.prototype.__proto__ = EventEmitter.prototype

ServerClientMock = (browserSocket) ->
  EventEmitter.call this
  @browserSocket = browserSocket
  return
ServerClientMock.prototype =
  broadcast: (message) ->
    @_serverSocket._clients.forEach (client) =>
      if @browserSocket != client
        client.emit 'message', JSON.stringify message
ServerClientMock.prototype.__proto__ = EventEmitter.prototype

BrowserSocketMock =
exports.BrowserSocketMock = (@serverSocket) ->
  EventEmitter.call this
  @serverClient = new ServerClientMock this
  return
BrowserSocketMock.prototype =
  connect: ->
    @serverSocket.emit 'connection', @serverClient
  send: (message) ->
    @serverClient.emit 'message', JSON.stringify message
BrowserSocketMock.prototype.__proto__ = EventEmitter.prototype
