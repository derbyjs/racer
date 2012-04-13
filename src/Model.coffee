{EventEmitter} = require 'events'
Memory = require './Memory'
{eventRegExp} = require './path'
{mergeAll} = require './util'

Model = module.exports = ->
  @_memory = new Memory
  @_count = id: 0
  # Set max listeners to unlimited
  @setMaxListeners 0
  @mixinEmit 'init', this
  return

mergeAll Model::, EventEmitter::,

  id: -> '$_' + @_clientId + '_' + (@_count.id++).toString 36

  ## Socket.io communication ##

  connected: true
  canConnect: true

  _setSocket: (@socket) ->
    @mixinEmit 'socket', this, socket

    @disconnect = ->
      socket.disconnect()

    @connect = (cb) ->
      if cb then socket.once 'connect', cb
      socket.socket.connect()

    @canConnect = true
    socket.on 'fatalErr', (msg) =>
      @canConnect = false
      @emit 'canConnect', false
      socket.disconnect()

    @connected = false
    onConnected = =>
      @emit 'connected', @connected
      @emit 'connectionStatus', @connected, @canConnect

    socket.on 'connect', =>
      @connected = true
      onConnected()

    socket.on 'disconnect', =>
      @connected = false
      # Slight delay after disconnect so that offline doesn't flash on reload
      setTimeout onConnected, 400
    # Needed in case page is loaded from cache while offline
    socket.on 'connect_failed', onConnected

  ## Scoped Models ##

  # Create a model object scoped to a particular path
  # Example:
  #   user = model.at 'users.1'
  #   user.set 'username', 'brian'
  #   user.on 'push', 'todos', (todo) ->
  at: (segment, absolute) -> Object.create this, _at: value:
    if (at = @_at) && !absolute
      if segment == '' then at else at + '.' + segment
    else segment.toString()

  parent: (levels = 1) ->
    return this unless at = @_at
    segments = at.split '.'
    return @at segments.slice(0, segments.length - levels).join('.'), true

  path: -> @_at || ''

  leaf: (path = @_at || '') ->
    i = path.lastIndexOf '.'
    return path.substr i + 1

  ## Model events ##

  # EventEmitter::on/addListener and once return this. The Model equivalents
  # return the listener instead, since it is made internally for method
  # subscriptions and may need to be passed to removeListener

  _on: EventEmitter::on
  on: (type, pattern, callback) ->
    @_on type, listener = eventListener type, pattern, callback, @_at
    return listener

  _once: EventEmitter::once
  once: (type, pattern, callback) ->
    listener = eventListener type, pattern, callback, @_at
    @_on type, g = =>
      matches = listener arguments...
      @removeListener type, g  if matches
    return listener

  # Used to pass an additional argument to local events. This value is
  # added to the event arguments in txns/mixin.Model
  # Example:
  #   model.pass(ignore: domId).move 'arr', 0, 2
  pass: (arg) -> Object.create this, _pass: value: arg

Model::addListener = Model::on

eventListener = (method, pattern, callback, at) ->
  if at
    if typeof pattern is 'string'
      pattern = at + '.' + pattern
    else if pattern.call
      callback = pattern
      pattern = at
    else
      throw new Error 'Unsupported event pattern on scoped model'

  else
    # on(type, listener)
    # Test for function by looking for call, since pattern can be a regex,
    # which has a typeof == 'function' as well
    return pattern if pattern.call

  # on(method, pattern, callback)
  re = eventRegExp pattern
  return (methodArgs, out, isLocal, pass) ->
    path = methodArgs[0]
    if re.test path
      args = methodArgs.slice(1)
      argsForEmit = re.exec(path).slice(1).concat args
      argsForEmit.push out, isLocal, pass
      callback argsForEmit...
      return true
