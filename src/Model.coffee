MemorySync = require './adapters/MemorySync'
pathParser = require './pathParser'
{EventEmitter} = require 'events'
{mergeAll: merge} = require './util'

Model = module.exports = (@_clientId = '', AdapterClass = MemorySync) ->
  self = this
  self._adapter = adapter = new AdapterClass

  for {init} in Model.mixins
    init.call self if init

  # The value of @_silent is checked in @_addOpAsTxn. It can be used to perform an
  # operation without triggering an event locally, such as model.silent.set
  # It only silences the first local event, so events on public paths that
  # get synced to the server are still emitted
  self.silent = Object.create self, _silent: value: true

  return


## Socket.io communication ##

Model::connected = true
Model::canConnect = true

Model::_setSocket = (socket) ->
  self = this
  self.socket = socket

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


## Model events ##

# Used to pass an additional argument to local events. This value is
# added to the event arguments in mixin.stm
# Example: model.with(ignore: domId).move 'arr', 0, 2
Model::with = (options) -> Object.create this, _with: value: options

merge Model::, EventEmitter::,
  _eventListener: (method, pattern, callback) ->
    # on(type, listener)
    # Test for function by looking for call, since pattern can be a regex,
    # which has a typeof == 'function' as well
    return pattern if pattern.call
    
    # on(method, pattern, callback)
    re = pathParser.eventRegExp pattern
    return ([path, args...], isLocal, _with) ->
      if re.test path
        callback re.exec(path).slice(1).concat(args, isLocal, _with)...
        return true

  # EventEmitter::on/addListener and once return this. The Model equivalents
  # return the listener instead, since it is made internally for method
  # subscriptions and may need to be passed to removeListener

  _on: EventEmitter::on
  on: (type, pattern, callback) ->
    @_on type, listener = @_eventListener type, pattern, callback
    return listener

  once: (type, pattern, callback) ->
    listener = @_eventListener type, pattern, callback
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
Model.mixins = []
Model.accessors = {}
Model.mutators = {}
onMixins = []
Model.mixin = (mixin) ->
  Model.mixins.push mixin
  merge Model::, proto if proto = mixin.proto
  merge Model, static if static = mixin.static

  for category in ['accessors', 'mutators']
    cache = Model[category]
    if objs = mixin[category] then for name, obj of objs
      Model::[name] = cache[name] = fn = obj.fn
      for key, value of obj
        continue if key is 'fn'
        fn[key] = value

  onMixins.push onMixin  if onMixin = mixin.onMixin
  for onMixin in onMixins
    onMixin Model.mutators, Model.accessors

  return Model

Model.mixin require './mixin.subscribe'
Model.mixin require './mixin.refs'
Model.mixin require './mixin.stm'
Model.mixin require './mixin.ot'
