transaction = require './transaction'
pathParser = require './pathParser'
MemorySync = require './adapters/MemorySync'
TxnApplier = require './TxnApplier'
RefHelper = require './RefHelper'

Model = module.exports = (@_clientId = '', AdapterClass = MemorySync) ->
  self = this
  self._initAdapter self._adapter = new AdapterClass
  
  self._storeSubs = []  # Paths in the store that this model is subscribed to
  self._eventSubs = {}  # Record of Model.on event subscriptions
  
  self._txnCount = 0
  self._txns = txns = {}
  self._txnQueue = txnQueue = []
  
  txnApplier = new TxnApplier
    applyTxn: (txn) -> self._applyTxn txn
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
      socket.emit 'txn', txn
    
    # Request any transactions that may have been missed
    @_reqNewTxns = -> socket.emit 'txnsSince', adapter.ver + 1
    
    socket.on 'txn', onTxn
    socket.on 'txnNum', @_onTxnNum
    socket.on 'txnOk', (base, txnId, num) ->
      if txn = txns[txnId]
        txn[0] = base
        onTxn txn, num
    socket.on 'txnErr', (err, txnId) ->
      txn = txns[txnId]
      if txn && (callback = txn.callback) && err != 'duplicate'
        args = transaction.args txn
        args.unshift err
        callback args...
      removeTxn txnId
    socket.on 'fatalErr', -> self._emitSimple 'fatal_error'
    
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
      socket.emit 'sub', clientId, storeSubs, adapter.ver
      # Resend all transactions in the queue
      commit txns[id] for id in txnQueue
      # Set an interval to check for transactions that have been in the queue
      # for too long and resend them
      resendInterval = setInterval resend, RESEND_INTERVAL unless resendInterval
    socket.on 'disconnect', ->
      # Stop resending transactions while disconnected
      clearInterval resendInterval if resendInterval
      resendInterval = null


  ## Model events ##
  
  on: (method, pattern, callback) ->
    # Test for function, since pattern can be a regex or string
    if pattern.call
      # on(name, callback)
      sub = pattern
    else
      # on(method, pattern, callback)
      re = pathParser.regExp pattern
      sub = [re, callback]
    subs = @_eventSubs
    if subs[method] is undefined
      subs[method] = [sub]
    else
      subs[method].push sub
  
  _emitSimple: (name) ->
    return unless subs = @_eventSubs[name]
    for callback in subs
      callback()
  
  _emit: (method, [path, args...]) ->
    return unless subs = @_eventSubs[method]
    refHelper = @_refHelper
    emitPathEvents = (path) ->
      for [re, callback] in subs
        if re.test path
          callback.apply null, re.exec(path).slice(1).concat(args)
    emitPathEvents path
    # Emit events on any references that point to the path or any of its
    # ancestor paths.
    refHelper.notifyPointersTo path, method, args, emitPathEvents
  
  _initAdapter: (adapter) ->
    self = this
    @_refHelper = refHelper = new RefHelper self
    adapter.__set = adapter.set
    adapter.set = (path, value, ver, options = {}) ->
      out = adapter.__set path, value, ver, options
      # Save a record of any references being set
      refHelper.setRefs path, ref, value.$k, options if value && ref = value.$r
      # Check to see if setting to a reference's key. If so, update references
      refHelper.updateRefsForKey path, options
      return out
  
  # Creates a reference object for use in model data methods
  ref: (ref, key, arrOnly) ->
    if arrOnly
      return $r: ref, $k: key, $o: arrOnly
    if key? then $r: ref, $k: key else $r: ref
  
  
  ## Transaction handling ##
  
  _nextTxnId: -> @_clientId + '.' + @_txnCount++
  
  _addTxn: (method, args..., callback) ->
    # Create a new transaction and add it to a local queue
    id = @_nextTxnId()
    ver = if @_force then null else @_adapter.ver
    @_txns[id] = txn = [ver, id, method, args...]
    txn.callback = callback
    @_txnQueue.push id
    # Update the transaction's path with a dereferenced path
    path = txn[3] = args[0] = @_specModel()[1]
    # Apply a private transaction immediately and don't send it to the store
    return @_applyTxn txn if pathParser.isPrivate path
    # Emit an event on creation of the transaction
    @_emit method, args
    # Send it over Socket.IO or to the store on the server
    @_commit txn
  
  _applyTxn: (txn) ->
    method = transaction.method txn
    args = transaction.args txn
    args.push transaction.base txn
    @_adapter[method] args...
    @_removeTxn transaction.id txn
    @_emit method, args
    callback null, transaction.args(txn)... if callback = txn.callback
  
  # TODO Will re-calculation of speculative model every time result
  #      in assignemnts to vars becoming stale?
  _specModel: ->
    adapter = @_adapter
    if len = @_txnQueue.length
      # Then generate a speculative model
      obj = Object.create adapter.get()
      i = 0
      while i < len
        # Apply each pending operation to the speculative model
        txn = @_txns[@_txnQueue[i++]]
        args = transaction.args txn
        args.push adapter.ver, obj: obj, proto: true
        path = adapter[transaction.method txn] args...
    return [obj, path]
  
  
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

  remove: (path, startIndex, howMany, callback) ->
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
