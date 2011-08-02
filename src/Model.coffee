transaction = require './transaction'
pathParser = require './pathParser'
MemorySync = require './adapters/MemorySync'
TxnApplier = require './TxnApplier'
RefHelper = require './RefHelper'
EventEmitter = require('events').EventEmitter
merge = require('./utils').merge

Model = module.exports = (@_clientId = '', AdapterClass = MemorySync) ->
  self = this
  self._adapter = adapter = new AdapterClass
  self._initRefs adapter

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
  
  self._txnCount = 0
  self._txns = txns = {}
  self._txnQueue = txnQueue = []
  
  txnApplier = new TxnApplier
    applyTxn: (txn) -> self._applyTxn txn if transaction.base(txn) > adapter.ver
    onTimeout: -> self._reqNewTxns()

  self._onTxn = (txn, num) ->
    # Copy the callback onto this transaction if it matches one in the queue
    if queuedTxn = txns[transaction.id txn]
      txn.callback = queuedTxn.callback
    txnApplier.add txn, num
  
  self._onTxnNum = (num) ->
    # Reset the number used to keep track of pending transactions
    txnApplier.setIndex (+num || 0) + 1
    txnApplier.clearPending()
  
  self._removeTxn = (txnId) ->
    delete txns[txnId]
    if ~(i = txnQueue.indexOf txnId) then txnQueue.splice i, 1
    self._cache.invalidateSpecModelCache()
  
  # The value of @_force is checked in the @_addTxn method. It can be used to
  # create a transaction without conflict detection, such as model.force.set
  self.force = Object.create self, _force: value: true
  
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
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn, self._startId
    
    # Request any transactions that may have been missed
    @_reqNewTxns = -> socket.emit 'txnsSince', adapter.ver + 1, self._startId
    
    socket.on 'txn', onTxn
    socket.on 'txnNum', @_onTxnNum
    socket.on 'txnOk', (txnId, base, num) ->
      if txn = txns[txnId]
        txn[0] = base
        onTxn txn, num
    socket.on 'txnErr', (err, txnId) ->
      txn = txns[txnId]
      if txn && (callback = txn.callback)
        args = transaction.args txn
        args.unshift err
        callback args...
      removeTxn txnId
    socket.on 'fatalErr', -> self.emit 'fatal_error'
    
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
      # Establish subscriptions upon connecting and get any transactions
      # that may have been missed
      socket.emit 'sub', clientId, storeSubs, adapter.ver, self._startId
      # Resend all transactions in the queue
      commit txns[id] for id in txnQueue
      # Set an interval to check for transactions that have been in the queue
      # for too long and resend them
      resendInterval = setInterval resend, RESEND_INTERVAL unless resendInterval
    socket.on 'disconnect', ->
      # Stop resending transactions while disconnected
      clearInterval resendInterval if resendInterval
      resendInterval = null
  
  
  ## Transaction handling ##
  
  _nextTxnId: -> @_clientId + '.' + @_txnCount++
  
  _addTxn: (method, args..., callback) ->
    # Create a new transaction and add it to a local queue
    id = @_nextTxnId()
    ver = if @_force then null else @_adapter.ver
    @_txns[id] = txn = [ver, id, method, args...]
    txn.callback = callback
    @_txnQueue.push id
    txn = @_refHelper.dereferenceTxn txn, @_specModel()
    args[0] = path = txn[3]
    # Apply a private transaction immediately and don't send it to the store
    if pathParser.isPrivate path
      @_cache.invalidateSpecModelCache()
      return @_applyTxn txn
    # Emit an event on creation of the transaction
    @emit method, args
    # Send it over Socket.IO or to the store on the server
    @_commit txn
  
  _applyTxn: (txn) ->
    method = transaction.method txn
    args = transaction.args txn
    args.push transaction.base txn
    @_adapter[method] args...
    @_removeTxn transaction.id txn
    @emit method, args
    callback null, transaction.args(txn)... if callback = txn.callback
  
  # TODO Will re-calculation of speculative model every time result
  #      in assignemnts to vars becoming stale?
  _specModel: ->
    cache = @_cache
    if lastReplayedTxnId = cache.lastReplayedTxnId
      if cache.lastReplayedTxnId == @_txnQueue[@_txnQueue.length-1]
        return [cache.obj, cache.path]
      obj = cache.obj
      replayFrom = 1 + @_txnQueue.indexOf cache.lastReplayedTxnId
    else
      replayFrom = 0

    adapter = @_adapter
    if len = @_txnQueue.length
      # Then generate a speculative model
      unless obj
        obj = cache.obj = Object.create adapter.get()
      i = replayFrom
      while i < len
        # Apply each pending operation to the speculative model
        txn = @_txns[@_txnQueue[i++]]
        args = transaction.args txn
        args.push adapter.ver, obj: obj, proto: true, returnMeta: true
        meta = adapter[transaction.method txn] args...
        path = meta.path
      cache.obj = obj
      cache.path = path
      cache.lastReplayedTxnId = transaction.id txn
    return [obj, path]
  
  ## Model references handling ##

  _initRefs: (adapter) ->
    @_refHelper = refHelper = new RefHelper @
    adapter.__set = adapter.set
    adapter.set = (path, value, ver, options = {}) ->
      # Save a record of any references being set
      refHelper.$indexRefs path, ref, value.$k, ver, options if value && ref = value.$r
      out = @__set path, value, ver, options
      # Check to see if setting to a reference's key. If so, update references
      refHelper.updateRefsForKey path, ver, options
      return out

    adapter.__del = adapter.del
    adapter.del = (path, ver, options = {}) ->
      out = @__del path, ver, options
      refHelper.cleanupPointersTo path, options
      return out

    adapter.__remove = adapter.remove
    adapter.remove = (path, startIndex, howMany, ver, options = {}) ->
      out = @__remove path, startIndex, howMany, ver, options
      # Check to see if setting to a reference's key. If so, update references
      refHelper.updateRefsForKey path, ver, options
      return out
    
    ['push', 'unshift'].forEach (method) ->
      adapter['__' + method] = adapter[method]
      adapter[method] = (path, values..., ver, options) ->
        if options is undefined
          options = {}
        if options.constructor != Object
          values.push ver
          ver = options
          options = {}
        out = @['__' + method] path, values..., ver, options
        # Check to see if setting to a reference's key. If so, update references
        refHelper.updateRefsForKey path, ver, options
        return out

    ['pop', 'shift'].forEach (method) ->
      adapter['__' + method] = adapter[method]
      adapter[method] = (path, ver, options = {}) ->
        out = @['__' + method] path, ver, options
        # Check to see if setting to a reference's key. If so, update references
        refHelper.updateRefsForKey path, ver, options
        return out

    ['insertAfter', 'insertBefore'].forEach (method) ->
      adapter['__' + method] = adapter[method]
      adapter[method] = (path, index, value, ver, options = {}) ->
        out = @['__' + method] path, index, value, ver, options
        # Check to see if setting to a reference's key. If so, update references
        refHelper.updateRefsForKey path, ver, options
        return out

    adapter.__splice = adapter.splice
    adapter.splice = (path, startIndex, removeCount, newMembers..., ver, options) ->
      if options is undefined
        options = {}
      if options.constructor != Object
        newMembers.push ver
        ver = options
        options = {}

      out = @__splice path, startIndex, removeCount, newMembers..., ver, options
      # Check to see if setting to a reference's key. If so, update references
      refHelper.updateRefsForKey path, ver, options
      return out

  # Creates a reference object for use in model data methods
  ref: RefHelper::ref
  
  ## Data accessor and mutator methods ##
  
  get: (path) -> @_adapter.get path, @_specModel()[0]
  
  set: (path, value, callback) ->
    @_addTxn 'set', path, value, callback
    return value
  
  del: (path, callback) ->
    @_addTxn 'del', path, callback

  ## Array methods ##
  
  push: (path, values..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      values.push callback
      callback = null
    @_addTxn 'push', path, values..., callback

  pop: (path, callback) ->
    @_addTxn 'pop', path, callback

  unshift: (path, values..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      values.push callback
      callback = null
    @_addTxn 'unshift', path, values..., callback

  shift: (path, callback) ->
    @_addTxn 'shift', path, callback

  insertAfter: (path, afterIndex, value, callback) ->
    @_addTxn 'insertAfter', path, afterIndex, value, callback

  insertBefore: (path, beforeIndex, value, callback) ->
    @_addTxn 'insertBefore', path, beforeIndex, value, callback

  remove: (path, startIndex, howMany = 1, callback) ->
    @_addTxn 'remove', path, startIndex, howMany, callback

  splice: (path, startIndex, removeCount, newMembers..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      newMembers.push callback
      callback = null
    @_addTxn 'splice', path, startIndex, removeCount, newMembers..., callback

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
  refHelper = @_refHelper
  return ([path, args...]) ->
    emitPathEvent = (path) ->
      callback re.exec(path).slice(1).concat(args)... if re.test path
    emitPathEvent path
    # Emit events on any references that point to the path or any of its
    # ancestor paths
    refHelper.notifyPointersTo path, method, args, emitPathEvent

# EventEmitter::addListener and once return this. The Model equivalents return
# the listener instead, since it is made internally for method subscriptions
# and may need to be passed to removeListener

Model::_on = EventEmitter::on
Model::on = Model::addListener = (type, pattern, callback) ->
  @_on type, listener = @_eventListener type, pattern, callback
  return listener

Model::_once = EventEmitter::once
Model::once = (type, pattern, callback) ->
  @_once type, listener = @_eventListener type, pattern, callback
  return listener
