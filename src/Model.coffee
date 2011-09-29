transaction = require './transaction'
pathParser = require './pathParser'
MemorySync = require './adapters/MemorySync'
RefHelper = require './RefHelper'
{EventEmitter} = require 'events'
merge = require('./util').merge
mutators = require './mutators'
arrayMutators = mutators.array
mutatorNames = Object.keys(mutators.basic).concat Object.keys(mutators.array)

Model = module.exports = (@_clientId = '', AdapterClass = MemorySync) ->
  self = this
  self._adapter = adapter = new AdapterClass

  mixins = Model._mixins
  for mixin in mixins
    init.call @ if init = mixin.init

  # Paths in the store that this model is subscribed to. These get set with
  # store.subscribe, and must be sent to the store upon connecting
  self._storeSubs = []
  
  # The value of @_force is checked in @_addOpAsTxn. It can be used to create a
  # transaction without conflict detection, such as model.force.set
  self.force = Object.create self, _force: value: true

  # The value of @_silent is checked in @_addOpAsTxn. It can be used to perform an
  # operation without triggering an event locally, such as model.silent.set
  # It only silences the first local event, so events on public paths that
  # get synced to the server are still emitted
  self.silent = Object.create self, _silent: value: true

  self._refHelper = refHelper = new RefHelper self
  for method in mutatorNames
    do (method) ->
      self.on method, ([path, args...]) ->
        # Emit events on any references that point to the path or any of its
        # ancestor paths
        refHelper.notifyPointersTo path, @get(), method, args

  return

Model:: =
  ## Socket.io communication ##
  
  _setSocket: (socket) ->
    @socket = socket
    self = this
    adapter = @_adapter

    @canConnect = true
    socket.on 'fatalErr', ->
      self.canConnect = false
      self.emit 'canConnect', false
      socket.disconnect()
    
    @connected = false
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
    for mixin in mixins
      setup.call @, socket if setup = mixin.setupSocket

  ## Model reference functions ##

  # Creates a reference object for use in model data methods
  ref: RefHelper::ref
  arrayRef: RefHelper::arrayRef

  ## Data accessor and mutator methods ##
  
  get: (path) ->
    {val, ver} = @_adapter.get path, @_specModel()[0]
    return val
  
  set: (path, val, callback) ->
    if v = val.$ot
      # TODO Only allow val to appear to user only
      #      if/once the path is in the permanent, not
      #      speculative model
      # TODO Eval path to refs
      adapter.set path, val, ver
      return v
    else
      @_addOpAsTxn 'set', path, val, callback
      return val
  
  setNull: (path, value, callback) ->
    obj = @get path
    return obj  if `obj != null`
    @set path, value, callback

  # STM del
  del: (path, callback) ->
    @_addOpAsTxn 'del', path, callback

  incr: (path, byNum, callback) ->
    # incr(path, callback)
    if typeof byNum is 'function'
      callback = byNum
      byNum = 1
    # incr(path)
    else if typeof byNum isnt 'number'
      byNum = 1
    @set path, (@get(path) || 0) + byNum, callback

  ## Array methods ##
  
  push: (path, values..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      values.push callback
      callback = null
    @_addOpAsTxn 'push', path, values..., callback

  pop: (path, callback) ->
    @_addOpAsTxn 'pop', path, callback

  unshift: (path, values..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      values.push callback
      callback = null
    @_addOpAsTxn 'unshift', path, values..., callback

  shift: (path, callback) ->
    @_addOpAsTxn 'shift', path, callback

  insertAfter: (path, afterIndex, value, callback) ->
    @_addOpAsTxn 'insertAfter', path, afterIndex, value, callback

  insertBefore: (path, beforeIndex, value, callback) ->
    @_addOpAsTxn 'insertBefore', path, beforeIndex, value, callback

  remove: (path, start, howMany = 1, callback) ->
    # remove(path, start, callback)
    if typeof howMany is 'function'
      callback = howMany
      howMany = 1
    @_addOpAsTxn 'remove', path, start, howMany, callback

  splice: (path, startIndex, removeCount, newMembers..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      newMembers.push callback
      callback = null
    @_addOpAsTxn 'splice', path, startIndex, removeCount, newMembers..., callback

  move: (path, from, to, callback) ->
    @_addOpAsTxn 'move', path, from, to, callback

## Model events ##

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

Model._mixins = []
Model.mixin = (mixin) ->
  @_mixins.push mixin
  merge Model::, proto if proto = mixin.proto
  merge Model, static if static = mixin.static

OT = require './ot'
Model.mixin OT

STM = require './stm'
Model.mixin STM
