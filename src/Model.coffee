transaction = require './transaction'
pathParser = require './pathParser'
MemorySync = require './adapters/MemorySync'
TxnApplier = require './TxnApplier'
RefHelper = require './RefHelper'
specHelper = require './specHelper'
{EventEmitter} = require 'events'
{merge} = require './util'
mutators = require './mutators'
arrayMutators = mutators.array
mutatorNames = Object.keys(mutators.basic).concat Object.keys(mutators.array)

Model = module.exports = (@_clientId = '', AdapterClass = MemorySync) ->
  self = this
  self._adapter = adapter = new AdapterClass

  self._cache =
    invalidateSpecModelCache: ->
      delete @obj
      delete @lastReplayedTxnId
      delete @path
  # Paths in the store that this model is subscribed to. These get set with
  # store.subscribe, and must be sent to the store upon connecting
  self._storeSubs = []
  # The startId is the ID of the last Redis restart. This is sent along with
  # each versioned message from the Model so that the Store can map the model's
  # version number to the version number of the Stm in case of a Redis failure
  self._startId = ''

  # atomic models that have been generated stored by atomic transaction id.
  self._atomicModels = {}

  self._txnCount = 0
  self._txns = txns = {}
  self._txnQueue = txnQueue = []

  txnApplier = new TxnApplier
    applyTxn: (txn) ->
      if transaction.base(txn) > adapter.ver
        self._applyTxn txn, !txn.emitted && @_clientId != transaction.clientId txn
    onTimeout: -> self._reqNewTxns()

  self._onTxn = (txn, num) ->
    # Copy meta properties onto this transaction if it matches one in the queue
    if queuedTxn = txns[transaction.id txn]
      txn.callback = queuedTxn.callback
      txn.emitted = queuedTxn.emitted
    txnApplier.add txn, num

  self._onTxnNum = (num) ->
    # Reset the number used to keep track of pending transactions
    txnApplier.setIndex (+num || 0) + 1
    txnApplier.clearPending()

  self._removeTxn = (txnId) ->
    delete txns[txnId]
    if ~(i = txnQueue.indexOf txnId) then txnQueue.splice i, 1
    self._cache.invalidateSpecModelCache()
  
  # The value of @_force is checked in @_addOpTxn. It can be used to create a
  # transaction without conflict detection, such as model.force.set
  self.force = Object.create self, _force: value: true

  # The value of @_silent is checked in @_addOpTxn. It can be used to perform an
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
  
  _commit: ->
  _reqNewTxns: ->
  _setSocket: (socket) ->
    @socket = socket
    self = this
    adapter = @_adapter
    txns = @_txns
    txnQueue = @_txnQueue
    onTxn = @_onTxn
    removeTxn = @_removeTxn
    
    @_commit = commit = (txn) ->
      return unless socket.socket.connected
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn, self._startId
    
    # Request any transactions that may have been missed
    @_reqNewTxns = -> socket.emit 'txnsSince', adapter.ver + 1, self._startId
    
    socket.on 'txn', onTxn
    socket.on 'txnNum', @_onTxnNum
    socket.on 'txnOk', (txnId, base, num) ->
      if txn = txns[txnId]
        transaction.base txn, base
        onTxn txn, num
    socket.on 'txnErr', (err, txnId) ->
      txn = txns[txnId]
      if txn && (callback = txn.callback)
        args = transaction.args(txn).slice 0
        args.unshift err
        callback args...
      removeTxn txnId
    
    @canConnect = true
    socket.on 'fatalErr', ->
      self.canConnect = false
      self.emit 'canConnect', false
      socket.disconnect()
    
    @connected = false
    onConnected = ->
      self.emit 'connected', self.connected
      self.emit 'connectionStatus', self.connected, self.canConnect
    
    clientId = @_clientId
    storeSubs = @_storeSubs
    resendInterval = null
    resend = ->
      now = +new Date
      for id in txnQueue
        txn = txns[id]
        return if txn.timeout > now
        commit txn
    socket.on 'connect', ->
      self.connected = true
      onConnected()
      # Establish subscriptions upon connecting and get any transactions
      # that may have been missed
      socket.emit 'sub', clientId, storeSubs, adapter.ver, self._startId
      # Resend all transactions in the queue
      commit txns[id] for id in txnQueue
      # Set an interval to check for transactions that have been in the queue
      # for too long and resend them
      resendInterval = setInterval resend, RESEND_INTERVAL unless resendInterval
    socket.on 'disconnect', ->
      self.connected = false
      # Stop resending transactions while disconnected
      clearInterval resendInterval if resendInterval
      resendInterval = null
      # Slight delay after disconnect so that offline doesn't flash on reload
      setTimeout onConnected, 200
    # Needed in case page is loaded from cache while offline
    socket.on 'connect_failed', onConnected
  
  
  ## Transaction handling ##
  
  _nextTxnId: -> @_clientId + '.' + @_txnCount++

  _normalizeIncomingTxn: (method, path, args...) ->
    # TODO
  
  # TODO There is a lot of mutation of txn going on here.
  #      Clean this up.
  _addOpTxn: (method, path, args..., callback) ->
    refHelper = @_refHelper
    model = @

    if {$r, $k} = refHelper.isArrayRef path, @_specModel()[0]
      [firstArgs, members] =
        (mutators.basic[method] || mutators.array[method]).splitArgs args
      members = members.map (member) ->
        return member if refHelper.isRefObj member
        # MUTATION
        model.set $r + '.' + member.id, member
        return {$r, $k: member.id.toString()}
      args = firstArgs.concat members

    # Convert id args to index args if we happen to be
    # using array ref mutator id api
    if mutators.array[method]?.indexesInArgs
      idAsIndex = refHelper.arrRefIndex args[0], path, @_specModel()[0]
    
    # Create a new transaction and add it to a local queue
    ver = if @_force then null else @_adapter.ver
    id = @_nextTxnId()
    txn = transaction.create base: ver, id: id, method: method, args: [path, args...]
    # NOTE: This converts the transaction
    txn = refHelper.dereferenceTxn txn, @_specModel()[0]
    @_txns[id] = txn
    txn.callback = callback
    @_txnQueue.push id

    txnArgs = transaction.args txn
    path = txnArgs[0]
    # Apply a private transaction immediately and don't send it to the store
    if pathParser.isPrivate path
      @_cache.invalidateSpecModelCache()
      return @_applyTxn txn, !txn.emitted && !@_silent

    if idAsIndex isnt undefined
      meta = txnArgs[1] # txnArgs[1] has form {id: id}
      meta.index = idAsIndex
      transaction.meta txn, meta

    # Emit an event on creation of the transaction
    unless @_silent
      @emit method, txnArgs, true
      txn.emitted = true

    txnArgs[1] = idAsIndex if idAsIndex isnt undefined

    # Send it over Socket.IO or to the store on the server
    @_commit txn
  
  _applyTxn: (txn, forceEmit) ->
    method = transaction.method txn
    txnArgs = transaction.args txn
    args = txnArgs.slice 0
    args.push transaction.base txn
    @_adapter[method] args...
    @_removeTxn transaction.id txn
    if forceEmit
      # For converting array ref index api back to id api
      args[1] = meta if meta = transaction.meta txn
      # Third argument is true for locally created transactions
      @emit method, args, 'callback' of txn
    callback null, txnArgs... if callback = txn.callback
  
  # TODO Will re-calculation of speculative model every time result
  #      in assignemnts to vars becoming stale?
  _specModel: ->
    cache = @_cache
    len = @_txnQueue.length
    if lastReplayedTxnId = cache.lastReplayedTxnId
      if cache.lastReplayedTxnId == @_txnQueue[len-1]
        return [cache.obj, cache.path]
      obj = cache.obj
      replayFrom = 1 + @_txnQueue.indexOf cache.lastReplayedTxnId
    else
      replayFrom = 0

    adapter = @_adapter
    if len
      # Then generate a speculative model
      unless obj
        # TODO adapter implementation details leaking in here
        # TODO Do not need Object.create here?
        obj = cache.obj = specHelper.create adapter._data

      i = replayFrom
      while i < len
        # Apply each pending operation to the speculative model
        txn = @_txns[@_txnQueue[i++]]
        args = transaction.args(txn).slice 0
        args.push adapter.ver, obj, proto: true, returnMeta: true
        meta = adapter[transaction.method txn] args...
        path = meta.path
      cache.obj = obj
      cache.path = path
      cache.lastReplayedTxnId = transaction.id txn
    return [obj, path]

  snapshot: ->
    model = new AtomicModel @_nextTxnId(), this
    model._adapter = adapter.snapshot()
    return model

  atomic: (block, callback) ->
    #model = @snapshot()
    model = new AtomicModel @_nextTxnId(), this
    commit = (callback) ->
    abort = ->
    retry = ->

    if block.length == 1
      block model
      commit(callback)
    else if block.length == 2
      block model, commit
    else if block.length == 3
      block model, commit, abort
    else if block.length == 4
      block model, commit, abort, retry
  
  ## Model reference functions ##

  # Creates a reference object for use in model data methods
  ref: RefHelper::ref
  arrayRef: RefHelper::arrayRef
  
  ## Data accessor and mutator methods ##
  
  get: (path) ->
    {val, ver} = @_adapter.get path, @_specModel()[0]
    return val
  
  set: (path, value, callback) ->
    @_addOpTxn 'set', path, value, callback
    return value
  
  setNull: (path, value, callback) ->
    obj = @get path
    return obj  if `obj != null`
    @set path, value, callback
  
  del: (path, callback) ->
    @_addOpTxn 'del', path, callback
  
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
    @_addOpTxn 'push', path, values..., callback

  pop: (path, callback) ->
    @_addOpTxn 'pop', path, callback

  unshift: (path, values..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      values.push callback
      callback = null
    @_addOpTxn 'unshift', path, values..., callback

  shift: (path, callback) ->
    @_addOpTxn 'shift', path, callback

  insertAfter: (path, afterIndex, value, callback) ->
    @_addOpTxn 'insertAfter', path, afterIndex, value, callback

  insertBefore: (path, beforeIndex, value, callback) ->
    @_addOpTxn 'insertBefore', path, beforeIndex, value, callback

  remove: (path, start, howMany = 1, callback) ->
    # remove(path, start, callback)
    if typeof howMany is 'function'
      callback = howMany
      howMany = 1
    @_addOpTxn 'remove', path, start, howMany, callback

  splice: (path, startIndex, removeCount, newMembers..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      newMembers.push callback
      callback = null
    @_addOpTxn 'splice', path, startIndex, removeCount, newMembers..., callback

  move: (path, from, to, callback) ->
    @_addOpTxn 'move', path, from, to, callback

# Timeout in milliseconds after which sent transactions will be resent
Model._SEND_TIMEOUT = SEND_TIMEOUT = 10000
# Interval in milliseconds to check timeouts for queued transactions
Model._RESEND_INTERVAL = RESEND_INTERVAL = 2000

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

AtomicModel = require './AtomicModel'
