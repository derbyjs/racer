EventEmitter = require('events').EventEmitter

ServerSocketMock = exports.ServerSocketMock = ->
  EventEmitter.call this
  @_clients = []
  @on 'connection', (client) =>
    @_clients.push client._browserSocket
    client._serverSocket = this
  return
ServerSocketMock:: =
  broadcast: (message) ->
    for client in @_clients
      client.emit 'message', JSON.stringify message
  __proto__: EventEmitter::

ServerClientMock = (@_browserSocket) ->
  EventEmitter.call this
  return
ServerClientMock:: =
  broadcast: (message) ->
    for client in @_serverSocket._clients
      if @_browserSocket != client
        client.emit 'message', JSON.stringify message
  __proto__: EventEmitter::

BrowserSocketMock = exports.BrowserSocketMock = (@_serverSocket) ->
  EventEmitter.call this
  @_serverClient = new ServerClientMock this
  return
BrowserSocketMock:: =
  connect: ->
    @_serverSocket.emit 'connection', @_serverClient
  send: (message) ->
    @_serverClient.emit 'message', JSON.stringify message
  __proto__: EventEmitter::
