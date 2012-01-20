{EventEmitter} = require 'events'

callEmit = (target, name, args, async) ->
  return if name == 'newListener'
  if async then return process.nextTick ->
    callEmit target, name, args
  EventEmitter::emit.call target, name, args...

ServerSocketsMock = exports.ServerSocketsMock = ->
  EventEmitter.call this
  @_sockets = sockets = []
  @on 'connection', (socket) ->
    browserSocket = socket._browserSocket
    browserSocket.socket.connected = true
    sockets.push browserSocket
    EventEmitter::emit.call browserSocket, 'connect'
  @_disconnect = ->
    for browserSocket in sockets
      browserSocket._disconnect()
  return
ServerSocketsMock:: =
  emit: (name, args...) ->
    callEmit socket, name, args for socket in @_sockets
  __proto__: EventEmitter::

nextSocketId = 1

ServerSocketMock = (@_serverSockets, @_browserSocket) ->
  EventEmitter.call this
  @id = @_browserSocket.id
  return
ServerSocketMock:: =
  emit: (name, args...) ->
    callEmit @_browserSocket, name, args
  __proto__: EventEmitter::

BrowserSocketMock = exports.BrowserSocketMock = (@_serverSockets) ->
  EventEmitter.call this
  @id = nextSocketId++
  @_serverSocket = new ServerSocketMock @_serverSockets, this
  @socket = connected: false
  return
BrowserSocketMock:: =
  _disconnect: ->
    @socket.connected = false
    EventEmitter::emit.call this, 'disconnect'
  _connect: ->
    EventEmitter::emit.call @_serverSockets, 'connection', @_serverSocket
  emit: (name, args...) ->
    callEmit @_serverSocket, name, args, 'async'
  __proto__: EventEmitter::
