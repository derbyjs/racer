{EventEmitter} = require 'events'
{deepCopy} = require '../../lib/util'

serializeArgs = (args) ->
  if typeof args[args.length-1] is 'function'
    fn = args.pop()
    args = deepCopy args
    args.push fn
  else
    args = deepCopy args
    #args = JSON.parse JSON.stringify args
  return args

callEmit = (target, name, args, async) ->
  return if name == 'newListener'
  if async then return process.nextTick ->
    callEmit target, name, args
  args = serializeArgs args
  EventEmitter::emit.call target, name, args...

ServerSocketsMock = exports.ServerSocketsMock = ->
  EventEmitter.call this
  @setMaxListeners 0
  @_sockets = sockets = {}
  @on 'connection', (socket) ->
    browserSocket = socket._browserSocket
    browserSocket.socket.connected = true
    sockets[browserSocket._clientId] ||= browserSocket
    EventEmitter::emit.call browserSocket, 'connect'
  @_disconnect = ->
    for _, browserSocket of sockets
      browserSocket._disconnect()
    return
  return

ServerSocketsMock:: =
  emit: (name, args...) ->
    EventEmitter::emit.call @, name, args...
    callEmit socket, name, args for _, socket of @_sockets
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
  @socket =
    connected: false
    connect: =>
      @_serverSocket = new ServerSocketMock @_serverSockets, this
      EventEmitter::emit.call _serverSockets, 'connection', @_serverSocket
  return

BrowserSocketMock:: =
  __proto__: EventEmitter::

  _disconnect: disconnect = ->
    callEmit @_serverSocket, 'disconnect', [], false if @socket.connected
    @socket.connected = false
    EventEmitter::emit.call this, 'disconnect'

  disconnect: disconnect
  emit: (name, args...) ->
    callEmit @_serverSocket, name, args, 'async'
