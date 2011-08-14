{EventEmitter} = require 'events'

callEmit = (target, name, args, async) ->
  return if name == 'newListener'
  return setTimeout callEmit, 0, target, name, args if async
  args = JSON.parse JSON.stringify args
  EventEmitter::emit.call target, name, args...

ServerSocketsMock = exports.ServerSocketsMock = ->
  EventEmitter.call this
  @_sockets = []
  @on 'connection', (socket) =>
    browserSocket = socket._browserSocket
    @_sockets.push browserSocket
    EventEmitter::emit.call browserSocket, 'connect'
  @_disconnect = =>
    for browserSocket in @_sockets
      EventEmitter::emit.call browserSocket, 'disconnect'
  return
ServerSocketsMock:: =
  emit: (name, args...) ->
    callEmit socket, name, args for socket in @_sockets
  __proto__: EventEmitter::

ServerSocketMock = (@_serverSockets, @_browserSocket) ->
  EventEmitter.call this
  @broadcast =
    emit: (name, args...) =>
      for socket in @_serverSockets._sockets
        callEmit socket, name, args if @_browserSocket != socket
  return
ServerSocketMock:: =
  emit: (name, args...) -> callEmit @_browserSocket, name, args
  __proto__: EventEmitter::

BrowserSocketMock = exports.BrowserSocketMock = (@_serverSockets) ->
  EventEmitter.call this
  @_serverSocket = new ServerSocketMock @_serverSockets, this
  return
BrowserSocketMock:: =
  _connect: ->
    EventEmitter::emit.call @_serverSockets, 'connection', @_serverSocket
  emit: (name, args...) -> callEmit @_serverSocket, name, args, 'async'
  __proto__: EventEmitter::
