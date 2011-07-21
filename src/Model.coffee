transaction = require './transaction'
MemorySync = require './adapters/MemorySync'

Model = module.exports = (@_clientId = '') ->
  self = this
  self._adapter = new MemorySync
  self._subs = {}
  
  self._txnCount = 0
  self._txns = {}
  self._txnQueue = []
  
  # TODO: This makes transactions get applied in order, but it only works when
  # every version is received. It needs to be updated to handle subscriptions
  # to only a subset of the model
  pending = {}
  pendingTimeout = null
  self._onTxn = onTxn = (txn) ->
    base = transaction.base txn
    nextVer = self._adapter.ver + 1
    # Cache this transaction to be applied later if it is not the next version
    if base > nextVer
      unless pendingTimeout
        pendingTimeout = setTimeout ->
          self._reqNewTxns()
          pendingTimeout = null
        , PENDING_TIMEOUT
      return pending[base] = txn
    # Ignore this transaction if it is older than the next version
    return if base < nextVer
    # Otherwise, apply it immediately
    self._applyTxn txn
    if pendingTimeout
      clearTimeout pendingTimeout
      pendingTimeout = null
    # And apply any transactions that were waiting for this one to be received
    nextVer++
    while txn = pending[nextVer]
      self._applyTxn txn
      delete pending[nextVer++]
  
  self._removeTxn = (txnId) ->
    delete self._txns[txnId]
    txnQueue = self._txnQueue
    if ~(i = txnQueue.indexOf txnId) then txnQueue.splice i, 1
  
  return

Model:: =
  _send: -> false
  _reqNewTxns: ->
  _setSocket: (socket, config) ->
    self = this
    self.socket = socket
    socket.emit 'clientId', self._clientId
    socket.on 'txn', self._onTxn
    socket.on 'txnFail', self._removeTxn
    
    self._send = send = (txn) ->
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn
    
    # Request any transactions that may have been missed
    self._reqNewTxns = -> socket.emit 'txnsSince', self._adapter.ver + 1
    
    resendAll = ->
      txns = self._txns
      send txns[id] for id in self._txnQueue
    resendExpired = ->
      now = +new Date
      txns = self._txns
      for id in self._txnQueue
        txn = txns[id]
        return if txn.timeout > now
        send txn
    
    # Request missed transactions and send queued transactions on connect
    resendInterval = null
    socket.on 'connect', ->
      self._reqNewTxns()
      resendAll()
      unless resendInterval
        resendInterval = setInterval resendExpired, RESEND_INTERVAL
    socket.on 'disconnect', ->
      clearInterval resendInterval
      resendInterval = null

  on: (method, pattern, callback) ->
    re = if pattern instanceof RegExp then pattern else
      new RegExp '^' + pattern.replace(/\.|\*{1,2}/g, (match, index) ->
          # Escape periods
          return '\\.' if match is '.'
          # A single asterisk matches any single path segment
          return '([^\\.]+)' if match is '*'
          # A double asterisk matches any path segment or segments
          return if match is '**'
            # Use greedy matching at the end of the path and
            # non-greedy matching otherwise
            if pattern.length - index is 2 then '(.+)' else '(.+?)'
        ) + '$'
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
      i = 0
      props = path.split '.'
      while prop = props[i++]
        break unless next = refs[prop]
        refs = next
      refs = refs.$
      # refs is now the last thing that was in $refs along the path
      remainder = ''
      i--
      while prop = props[i++]
        remainder += '.' + prop
      @_adapter._forRef refs, @get(), (p) ->
        testPath p + remainder

  _nextTxnId: -> @_clientId + '.' + @_txnCount++
  _addTxn: (method, args...) ->
    # Create a new transaction and add it to a local queue
    id = @_nextTxnId()
    @_txns[id] = txn = [@_adapter.ver, id, method, args...]
    @_txnQueue.push id
    # Update the transaction's path with a dereferenced path
    txn[3] = args[0] = @_specModel()[1]
    # Emit an event on creation of the transaction
    @_emit method, args
    # Send it over Socket.IO or to the store on the server
    @_send txn
  _applyTxn: (txn) ->
    method = transaction.method txn
    args = transaction.args txn
    args.push transaction.base txn
    adapter = @_adapter
    adapter[method].apply adapter, args
    @_removeTxn transaction.id txn
    @_emit method, args
  
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
        path = adapter[transaction.method txn].apply adapter, args
    return [obj, path]
  
  get: (path) -> @_adapter.get path, @_specModel()[0]
  
  set: (path, value) ->
    @_addTxn 'set', path, value
    return value
  del: (path) ->
    @_addTxn 'del', path
  ref: (ref, key) ->
    if key? then $r: ref, $k: key else $r: ref

# Timeout in milliseconds after which missed transactions will be requested
Model._PENDING_TIMEOUT = PENDING_TIMEOUT = 500
# Timeout in milliseconds after which sent transactions will be resent
Model._SEND_TIMEOUT = SEND_TIMEOUT = 10000
# Interval in milliseconds to check timeouts for queued transactions
Model._RESEND_INTERVAL = RESEND_INTERVAL = 2000
