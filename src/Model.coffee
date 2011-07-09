Model = module.exports = ->
  self = this
  self._data = {}
  self._base = 0
  self._clientId = ''
  
  self._txnCount = 0
  self._txns = txns = {}
  self._txnQueue = txnQueue = []
  
  self._onTxn = (txn) ->
    [base, txnId, method, args...] = txn
    self['_' + method].apply self, args
    self._base = base
    self._removeTxn txnId
  
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
        self['_' + method].apply self, args
    else
      obj = self._data
    if path then self._lookup(path, obj: obj).obj else obj
  
  return

Model:: =
  _send: -> false
  _setSocket: (socket, config) ->
    socket.on 'txn', @_onTxn
    socket.on 'txnFail', @_removeTxn
    @_send = (txn) ->
      socket.emit 'txn', txn
      # TODO: Only return true if sent successfully
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
  
  set: (path, value) ->
    @_addTxn ['set', path, value]
    return value
  delete: (path) ->
    @_addTxn ['del', path]
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
