transaction = require './transaction'
MemorySync = require './adapters/MemorySync'

Model = module.exports = (@_clientId = '', AdapterClass = MemorySync) ->
  self = this
  self._adapter = new AdapterClass
  self._subs = {}
  
  self._txnCount = 0
  self._txns = {}
  self._txnQueue = []
  
  # TODO: This makes transactions get applied in order, but it only works when
  # every version is received. It needs to be updated to handle subscriptions
  # to only a subset of the model
  pending = {}
  pendingTimeout = null
  nextNum = 1
  self._onTxn = (txn, num) ->
    # Copy the callback onto this transaction if it matches one in the queue
    if queuedTxn = self._txns[transaction.id txn]
      txn.callback = queuedTxn.callback
    
    # Cache this transaction to be applied later if it is not the next version
    if num > nextNum
      unless pendingTimeout
        pendingTimeout = setTimeout ->
          self._reqNewTxns()
          pendingTimeout = null
        , PENDING_TIMEOUT
      return pending[num] = txn
    # Ignore this transaction if it is older than the next version
    return if num < nextNum
    # Otherwise, apply it immediately
    self._applyTxn txn
    if pendingTimeout
      clearTimeout pendingTimeout
      pendingTimeout = null
    # And apply any transactions that were waiting for this one to be received
    nextNum++
    while txn = pending[nextNum]
      self._applyTxn txn
      delete pending[nextNum++]
  
  self._onTxnNum = (num) ->
    # Reset the number used to keep track of pending transactions
    nextNum = +num + 1
    # Remove any old pending transactions
    for i of pending
      delete pending[i] if i < nextNum
  
  self.force = Object.create self, _force: value: true
  
  return

Model:: =
  _commit: -> false
  _reqNewTxns: ->
  _setSocket: (socket, config) ->
    self = this
    self.socket = socket
    
    socket.on 'txn', self._onTxn
    socket.on 'txnNum', self._onTxnNum
    socket.on 'txnOk', (base, txnId, num) ->
      if txn = self._txns[txnId]
        txn[0] = base
        self._onTxn txn, num
    socket.on 'txnErr', (err, txnId) ->
      txn = self._txns[txnId]
      if txn && (callback = txn.callback) && err != 'duplicate'
        args = transaction.args txn
        args.unshift err
        callback args...
      self._removeTxn txnId
    
    self._commit = commit = (txn) ->
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn
    
    # Request any transactions that may have been missed
    self._reqNewTxns = -> socket.emit 'txnsSince', self._adapter.ver + 1
    
    resendAll = ->
      txns = self._txns
      commit txns[id] for id in self._txnQueue
    resendExpired = ->
      now = +new Date
      txns = self._txns
      for id in self._txnQueue
        txn = txns[id]
        return if txn.timeout > now
        commit txn
    
    # Request missed transactions and send queued transactions on connect
    resendInterval = null
    socket.on 'connect', ->
      socket.emit 'sub', self._clientId, self.get '$subs'
      self._reqNewTxns()
      resendAll()
      unless resendInterval
        resendInterval = setInterval resendExpired, RESEND_INTERVAL
    socket.on 'disconnect', ->
      clearInterval resendInterval
      resendInterval = null

  on: (method, pattern, callback) ->
    re = transaction.pathRegExp pattern
    sub = [re, callback]
    subs = @_subs
    if subs[method] is undefined
      subs[method] = [sub]
    else
      subs[method].push sub
  _emit: (method, [path, args...]) ->
    return unless subs = @_subs[method]
    testPath = (path) ->
      for sub in subs
        re = sub[0]
        if re.test path
          sub[1].apply null, re.exec(path).slice(1).concat(args)
    # Emit events on the path
    testPath path
    # Emit events on any references that point to the path
    if refs = @get '$refs'
      self = this
      derefPath = (obj, props, i) ->
        remainder = ''
        while prop = props[i++]
          remainder += '.' + prop
        self._adapter._forRef obj, self.get(), (path) ->
          path += remainder
          testPath path
          checkRefs path
      checkRefs = (path) ->
        i = 0
        obj = refs
        props = path.split '.'
        while prop = props[i++]
          break unless next = obj[prop]
          derefPath next.$, props, i if next.$
          obj = next
      checkRefs path

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
    return @_applyTxn txn if transaction.privatePath path
    # Emit an event on creation of the transaction
    @_emit method, args
    # Send it over Socket.IO or to the store on the server
    @_commit txn
  _removeTxn: (txnId) ->
    delete @_txns[txnId]
    txnQueue = @_txnQueue
    if ~(i = txnQueue.indexOf txnId) then txnQueue.splice i, 1
  _applyTxn: (txn) ->
    method = transaction.method txn
    args = transaction.args txn
    args.push transaction.base txn
    adapter = @_adapter
    adapter[method] args...
    @_removeTxn transaction.id txn
    @_emit method, args
    callback null, transaction.args(txn)... if callback = txn.callback
  
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
  
  get: (path) -> @_adapter.get path, @_specModel()[0]
  
  set: (path, value, callback) ->
    @_addTxn 'set', path, value, callback
    return value
  del: (path, callback) ->
    @_addTxn 'del', path, callback
  
  ref: (ref, key) ->
    if key? then $r: ref, $k: key else $r: ref

  ## Array Methods ##
  push: (path, values..., callback) ->
    if 'function' != typeof callback && callback isnt undefined
      values.push callback
      callback = null
    @_addTxn 'push', path, values..., callback

# Timeout in milliseconds after which missed transactions will be requested
Model._PENDING_TIMEOUT = PENDING_TIMEOUT = 500
# Timeout in milliseconds after which sent transactions will be resent
Model._SEND_TIMEOUT = SEND_TIMEOUT = 10000
# Interval in milliseconds to check timeouts for queued transactions
Model._RESEND_INTERVAL = RESEND_INTERVAL = 2000
