MemorySync = require './adapters/MemorySync'
{eventRegExp} = require './pathParser'
{EventEmitter} = require 'events'
{mergeAll} = require './util'

Model = module.exports = (@_clientId = '', Adapter = MemorySync) ->
  @_adapter = new Adapter

  for {init} in Model.mixins
    init.call this if init

  return

Model:: =

  ## Socket.io communication ##

  connected: true
  canConnect: true

  _setSocket: (@socket) ->
    self = this

    self.canConnect = true
    socket.on 'fatalErr', ->
      self.canConnect = false
      self.emit 'canConnect', false
      socket.disconnect()

    self.connected = false
    onConnected = ->
      self.emit 'connected', self.connected
      self.emit 'connectionStatus', self.connected, self.canConnect

    socket.on 'connect', ->
      self.connected = true
      onConnected()

    socket.on 'disconnect', ->
      self.connected = false
      # Slight delay after disconnect so that offline doesn't flash on reload
      setTimeout onConnected, 200
    # Needed in case page is loaded from cache while offline
    socket.on 'connect_failed', onConnected

    for {setupSocket} in Model.mixins
      setupSocket.call @, socket if setupSocket

  query: require './query'

  ## Model Aliases ##
  # Create a model object scoped to a particular path
  # Example:
  # // Instead of writing
  # model.set ('users.1.username', 'brian');
  #
  # // You can use aliases to write
  # var user = model.at('users.1');
  # user.set('username', 'brian');
  #
  # // Aliases can also be leveraged for other mutators
  # // and for events as in the following code:
  # user.on('push', 'todos', function (todo) {
  # });
  at: (segment, absolute) -> Object.create this, _at: value:
    if (at = @_at) && !absolute
      if segment == '' then at else at + '.' + segment
    else segment.toString()

  parent: (levels = 1) ->
    return this unless at = @_at
    segments = at.split '.'
    return @at segments.slice(0, segments.length - levels).join('.'), true

  path: -> @_at || ''

  leaf: (path) ->
    path = @_at || '' unless path?
    i = path.lastIndexOf '.'
    return path.substr i + 1

  # Used to pass an additional argument to local events. This value is
  # added to the event arguments in mixin.stm
  # Example: model.pass(ignore: domId).move 'arr', 0, 2
  pass: (arg) -> Object.create this, _pass: value: arg


## Model events ##

eventListener = (method, pattern, callback, at) ->
  if at
    if typeof pattern is 'string'
      pattern = at + '.' + pattern
    else if pattern.call
      callback = pattern
      pattern = at
    else
      throw new Error 'Unsupported event pattern on model alias'

  else
    # on(type, listener)
    # Test for function by looking for call, since pattern can be a regex,
    # which has a typeof == 'function' as well
    return pattern if pattern.call

  # on(method, pattern, callback)
  re = eventRegExp pattern
  return ([path, args...], out, isLocal, pass) ->
    if re.test path
      argsForEmit = re.exec(path).slice(1).concat args
      argsForEmit.push out, isLocal, pass
      callback argsForEmit...
      return true

mergeAll Model::, EventEmitter::,
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
    self = this
    @_on type, g = ->
      matches = listener arguments...
      self.removeListener type, g  if matches
    return listener

Model::addListener = Model::on


## Mixins ##

# A mixin is an object literal with:
# proto:       methods to add to Model.prototype
# static:      class/static methods to add to Model
# init:        called from the Model constructor
# setupSocket: invoked inside Model::_setSocket with fn signature (socket) -> ...
# accessors:   getters
# mutators:    setters
# onMixin:     called with mutators and accessors after every mixin 

# NOTE: Order of mixins may be important because of dependencies.

makeMixable = (Klass) ->
  Klass.mixins = []
  Klass.accessors = {}
  Klass.mutators = {}
  onMixins = []
  Klass.mixin = (mixin) ->
    Klass.mixins.push mixin
    mergeAll Klass::, mixin.static, mixin.proto

    for category in ['accessors', 'mutators']
      cache = Klass[category]
      if methods = mixin[category] then for name, conf of methods
        Klass::[name] = cache[name] = fn = conf.fn
        for key, value of conf
          continue if key is 'fn'
          fn[key] = value

    onMixins.push onMixin  if onMixin = mixin.onMixin
    for onMixin in onMixins
      onMixin Klass.mutators, Klass.accessors

    return Klass

makeMixable Model

Model.mixin require './mixin.subscribe'
Model.mixin require './mixin.refs'
Model.mixin require './mixin.stm'
Model.mixin require './mixin.ot'
