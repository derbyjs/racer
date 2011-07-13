EventEmitter = require('events').EventEmitter

callEmit = (target, name, value, async) ->
  return if name == 'newListener'
  return setTimeout callEmit, 0, target, name, value if async
  EventEmitter::emit.call target, name, JSON.parse JSON.stringify value

ServerSocketsMock = exports.ServerSocketsMock = ->
  EventEmitter.call this
  @_sockets = []
  @on 'connection', (socket) =>
    browserSocket = socket._browserSocket
    @_sockets.push browserSocket
    EventEmitter::emit.call browserSocket, 'connect'
  return
ServerSocketsMock:: =
  emit: (name, value) -> callEmit socket, name, value for socket in @_sockets
  __proto__: EventEmitter::

ServerSocketMock = (@_serverSockets, @_browserSocket) ->
  EventEmitter.call this
  @broadcast =
    emit: (name, value) =>
      for socket in @_serverSockets._sockets
        callEmit socket, name, value if @_browserSocket != socket
  return
ServerSocketMock:: =
  emit: (name, value) -> callEmit @_browserSocket, name, value
  __proto__: EventEmitter::

BrowserSocketMock = exports.BrowserSocketMock = (@_serverSockets) ->
  EventEmitter.call this
  @_serverSocket = new ServerSocketMock @_serverSockets, this
  return
BrowserSocketMock:: =
  _connect: ->
    EventEmitter::emit.call @_serverSockets, 'connection', @_serverSocket
  emit: (name, value) -> callEmit @_serverSocket, name, value, 'async'
  __proto__: EventEmitter::
