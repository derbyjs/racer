transaction = require './transaction'

Model = module.exports = (@_clientId = '') ->
  self = this
  self._data = {}
  self._base = 0
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
    nextVer = self._base + 1
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
    socket.on 'txn', self._onTxn
    socket.on 'txnFail', self._removeTxn
    
    self._send = send = (txn) ->
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn
    
    # Request any transactions that may have been missed
    self._reqNewTxns = -> socket.emit 'txnsSince', self._base + 1
    
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
      self._reqNewTxns
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
    return if !subs = @_subs[method]
    for sub in subs
      re = sub[0]
      if re.test path
        sub[1].apply null, re.exec(path).slice(1).concat(args)

  _nextTxnId: -> @_clientId + '.' + @_txnCount++
  _addTxn: (method, args...) ->
    # Create a new transaction and add it to a local queue
    id = @_nextTxnId()
    @_txns[id] = txn = [@_base, id, method, args...]
    @_txnQueue.push id
    # Emit an event on creation of the transaction
    @_emit method, args
    # Send it over Socket.IO or to the store on the server
    @_send txn
    return id
  _applyTxn: (txn) ->
    method = transaction.method txn
    args = transaction.args txn
    @['_' + method].apply this, args
    @_base = transaction.base txn
    @_removeTxn transaction.id txn
    @_emit method, args

  _lookup: (path, {obj, addPath, proto, onRef}) ->
    next = obj || @_data
    get = @get
    props = if path and path.split then path.split '.' else []
    
    path = ''
    i = 0
    len = props.length
    while i < len
      obj = next
      prop = props[i++]
      
      # In speculative model operations, return a prototype referenced object
      if proto && !Object::isPrototypeOf(obj)
        obj = Object.create obj
      
      # Traverse down the next segment in the path
      next = obj[prop]
      if next is undefined
        # Return null if the object can't be found
        return {obj: null} unless addPath
        # If addPath is true, create empty parent objects implied by path
        next = obj[prop] = {}
      
      # Check for model references
      if ref = next.$r
        refObj = get ref
        if key = next.$k
          keyObj = get key
          path = ref + '.' + keyObj
          next = refObj[keyObj]
        else
          path = ref
          next = refObj
        if onRef
          remainder = [path].concat props.slice(i)
          onRef key, remainder.join('.')
      else
        # Store the absolute path traversed so far
        path = if path then path + '.' + prop else prop
    
    return obj: next, path: path, parent: obj, prop: prop
  
  get: (path) ->
    if len = @_txnQueue.length
      # Then generate a speculative model
      obj = Object.create @_data
      i = 0
      while i < len
        # Apply each pending operation to the speculative model
        txn = @_txns[@_txnQueue[i++]]
        args = transaction.args txn
        args.push obj: obj, proto: true
        @['_' + transaction.method txn].apply this, args
    else
      obj = @_data
    if path then @_lookup(path, obj: obj).obj else obj
  
  set: (path, value) ->
    @_addTxn 'set', path, value
    return value
  del: (path) ->
    @_addTxn 'del', path
  ref: (ref, key) ->
    if key? then $r: ref, $k: key else $r: ref

  _set: (path, value, options = {}) ->
    options.addPath = true
    out = @_lookup path, options
    try
      out.parent[out.prop] = value
    catch err
      throw new Error 'Model set failed on: ' + path
  _del: (path, options = {}) ->
    out = @_lookup path, options
    parent = out.parent
    prop = out.prop
    try
      if options.proto
        # In speculative models, deletion of something in the model data is
        # acheived by making a copy of the parent prototype's properties that
        # does not include the deleted property
        if prop of parent.__proto__
          obj = {}
          for key, value of parent.__proto__
            unless key is prop
              obj[key] = if typeof value is 'object'
                Object.create value
              else
                value
          parent.__proto__ = obj
      delete parent[prop]
    catch err
      throw new Error 'Model delete failed on: ' + path

# Timeout in milliseconds after which missed transactions will be requested
Model._PENDING_TIMEOUT = PENDING_TIMEOUT = 500
# Timeout in milliseconds after which sent transactions will be resent
Model._SEND_TIMEOUT = SEND_TIMEOUT = 10000
# Interval in milliseconds to check timeouts for queued transactions
Model._RESEND_INTERVAL = RESEND_INTERVAL = 2000