pathParser = require './pathParser'
MemorySync = require './adapters/MemorySync'
RefHelper = require './RefHelper'
{EventEmitter} = require 'events'
{merge} = require './util'

Model = module.exports = (@_clientId = '', AdapterClass = MemorySync) ->
  self = this
  self._adapter = adapter = new AdapterClass

  mixins = Model._mixins
  for {init} in mixins
    init.call self if init

  # Paths in the store that this model is subscribed to. These get set with
  # store.subscribe, and must be sent to the store upon connecting
  self._storeSubs = []

  # The value of @_silent is checked in @_addOpAsTxn. It can be used to perform an
  # operation without triggering an event locally, such as model.silent.set
  # It only silences the first local event, so events on public paths that
  # get synced to the server are still emitted
  self.silent = Object.create self, _silent: value: true

  self._refHelper = refHelper = new RefHelper self

  for method of Model._accessorNames
    continue if method is 'get'
    do (method) ->
      self.on method, ([path, args...]) ->
        # Emit events on any references that point to the path or any of its
        # ancestor paths
        refHelper.notifyPointersTo path, @get(), method, args

  return

Model:: =
  ## Socket.io communication ##
  
  _setSocket: (socket) ->
    self = this
    self.socket = socket
    adapter = self._adapter

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

    mixins = Model._mixins
    for {setupSocket} in mixins
      setupSocket.call @, socket if setupSocket

  ## Model reference functions ##

  # Creates a reference object for use in model data methods
  ref: RefHelper::ref
  
  # Creates an array reference object for use in model data methods
  arrayRef: RefHelper::arrayRef

## Model events ##

# TODO Make events a Model mixin?

merge Model::, EventEmitter::

Model::_eventListener = (method, pattern, callback) ->
  # on(type, listener)
  # Test for function by looking for call, since pattern can be a regex,
  # which has a typeof == 'function' as well
  return pattern if pattern.call
  
  # on(method, pattern, callback)
  re = pathParser.regExp pattern
  return ([path, args...]) ->
    if re.test path
      callback re.exec(path).slice(1).concat(args)...
      return true

# EventEmitter::addListener and once return this. The Model equivalents return
# the listener instead, since it is made internally for method subscriptions
# and may need to be passed to removeListener

Model::_on = EventEmitter::on
Model::on = Model::addListener = (type, pattern, callback) ->
  @_on type, listener = @_eventListener type, pattern, callback
  return listener

Model::once = (type, pattern, callback) ->
  listener = @_eventListener type, pattern, callback
  self = this
  @_on type, g = ->
    matches = listener arguments...
    self.removeListener type, g  if matches
  return listener

Model::constructor = Model

## Mixins ##

# A mixin is an object literal with:
# proto:       methods to add to Model.prototype
# static:      class/static methods to add to Model
# init:        called from the Model constructor
# setupSocket: invoked inside Model::_setSocket with fn signature (socket) -> ...
# accessors:   get, set, etc.

# NOTE: Order of mixins may be important because of dependencies.
Model._mixins = []
Model._accessorNames = {}
Model.mixin = (mixin) ->
  @_mixins.push mixin
  merge Model::, proto if proto = mixin.proto
  merge Model, static if static = mixin.static

  if accessors = mixin.accessors
    merge Model::, accessors
    Model._accessorNames[accessorName] = 1 for accessorName of accessors

OT = require './mixin.ot'
Model.mixin OT

STM = require './mixin.stm'
Model.mixin STM
