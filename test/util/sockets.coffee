{EventEmitter} = require 'events'
{deepCopy} = require '../../lib/util'

callEmit = (target, name, args, async) ->
  return if name == 'newListener'
  if async then return process.nextTick ->
    callEmit target, name, deepCopy(args)
  EventEmitter::emit.call target, name, deepCopy(args)...

ServerSocketsMock = exports.ServerSocketsMock = ->
  EventEmitter.call this
  @setMaxListeners 0
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
  @setMaxListeners 0
  @id = @_browserSocket.id
  @handshake = query: clientId: @_browserSocket._clientId
  return

ServerSocketMock:: =
  emit: (name, args...) ->
    callEmit @_browserSocket, name, args
  __proto__: EventEmitter::

BrowserSocketMock = exports.BrowserSocketMock = (@_serverSockets, @_clientId) ->
  EventEmitter.call this
  @setMaxListeners 0
  @id = nextSocketId++
  @_serverSocket = new ServerSocketMock @_serverSockets, this
  @socket = connected: false
  return

BrowserSocketMock:: =
  __proto__: EventEmitter::

  _disconnect: disconnect = ->
    @socket.connected = false
    EventEmitter::emit.call this, 'disconnect'
  disconnect: disconnect
  _connect: ->
    EventEmitter::emit.call @_serverSockets, 'connection', @_serverSocket
  emit: (name, args...) ->
    callEmit @_serverSocket, name, args, 'async'
