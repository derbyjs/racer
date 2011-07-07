Model = module.exports = ->
  self = this
  self._data = {}
  self._base = 0
  self._clientId = ''
  
  self._txnCount = 0
  self._txns = txns = {}
  self._txnQueue = txnQueue = []
  
  self._onTxn = onTxn = (txn) ->
    [base, txnId, method, args...] = txn
    setters[method].apply self, args
    self._base = base
    self._removeTxn txnId
  
  self._onMessage = (message) ->
    [type, content] = JSON.parse message
    switch type
      when 'txn'
        onTxn content
      when 'txnFail'
        self._removeTxn content
  
  self.get = (path) ->
    if len = txnQueue.length
      # Then generate a speculative model
      obj = Object.create self._data
      i = 0
      while i < len
        # Add the speculative model to each pending transactions by
        # appending to each txn's args
        txn = txns[txnQueue[i++]]
        [method, args...] = txn.op
        args.push obj: obj, proto: true
        setters[method].apply self, args
    else
      obj = self._data
    if path then self._lookup(path, obj: obj).obj else obj
  
  return

Model:: =
  _send: -> false
  _setSocket: (socket) ->
    socket.connect()
    socket.on 'message', @_onMessage
    @_send = (txn) ->
      socket.send ['txn', txn]
      # TODO: Only return true if sent successfully
      return true
  _setStm: (stm) ->
    onTxn = @_onTxn
    @_send = (txn) ->
      stm.commit txn, (err, ver) ->
        # TODO: Handle STM conflicts and other errors
        if ver
          txn[0] = ver
          onTxn txn
        return true
  _nextTxnId: -> @_clientId + '.' + @_txnCount++
  _addTxn: (op) ->
    # Wraps the op in a transaction
    # Places the transaction in a dictionary and queue
    # Sends the transaction over Socket.IO
    # Returns the transaction id
    base = @_base
    txn = op: op, base: base, sent: false
    id = @_nextTxnId()
    @_txns[id] = txn
    @_txnQueue.push id
    # TODO: Raise event on creation of transaction
    txn.sent = @_send [base, id, op...]
    return id
  _removeTxn: (txnId) ->
    delete @_txns[txnId]
    txnQueue = @_txnQueue
    if ~(i = txnQueue.indexOf txnId) then txnQueue.splice i, 1
  _lookup: (path, {obj, addPath, proto, onRef}) ->
    obj ||= @_data
    props = if path and path.split then path.split '.' else []
    get = @get
    props.reduce ({obj, path}, prop, i) ->
      
      # In speculative model operations, return a prototype referenced object
      if proto && !Object::isPrototypeOf(obj)
        obj = Object.create obj
      
      # Traverse down the next segment in the path
      next = obj[prop]
      if next is undefined
        # Return null if the object can't be found
        return 'obj': null unless addPath
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
          remainder = [path].concat props.slice(i+1)
          onRef key, remainder.join '.'
      else
        # Store the absolute path traversed so far
        path = if path then path + '.' + prop else prop
      
      if i == props.length - 1
        return obj: next, path: path, parent: obj, prop: prop
      return obj: next, path: path
    , obj: obj, path: ''
  
  set: (path, value) ->
    @_addTxn ['set', path, value]
  delete: (path) ->
    @_addTxn ['del', path]
  ref: (ref, key) ->
    if key? then $r: ref, $k: key else $r: ref

setters =
  set: (path, value, options = {}) ->
    options.addPath = true
    out = @_lookup path, options
    try
      out.parent[out.prop] = value
    catch err
      throw new Error 'Model set failed on: ' + path
  del: (path, options = {}) ->
    out = @_lookup path, options
    parent = out.parent
    prop = out.prop
    try
      if options.proto
        # In speculative models, deletion of something in the model data is
        # acheived by making a copy of the parent prototype's properties
        # that does not include the deleted property
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
