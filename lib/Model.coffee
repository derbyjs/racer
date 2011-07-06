_ = require './util'

Model = module.exports = ->
  self = this
  self._data = {}
  self._base = 0
  self._clientId = ''
  
  self._txnCount = 0
  self._txns = txns = {}
  self._txnQueue = txnQueue = []
  
  self._onMessage = (message) ->
    [type, content, meta] = JSON.parse message
    switch type
      when 'txn'
        [base, txnId, method, args...] = content
        setters[method].apply self, args
        self._base = base
        self._removeTxn txnId
      when 'txnFail'
        self._removeTxn content
  
  self.get = (path) ->
    if len = txnQueue.length
      obj = Object.create self._data
      i = 0
      while i < len
        txn = txns[txnQueue[i++]]
        [method, args...] = txn.op
        args.push obj: obj, proto: true
        setters[method].apply self, args
    else
      obj = self._data
    if path then self._lookup(path, obj: obj).obj else obj
  
  return

Model:: =
  _setSocket: (@_socket) ->
    @_socket.connect()
    @_socket.on 'message', @_onMessage
  _send: (message) ->
    if socket = @_socket
      socket.send message
      # TODO: Only return true if sent successfully
      return true
    else
      return false
  _nextTxnId: ->
    @_clientId + '.' + @_txnCount++
  _addTxn: (op) ->
    base = @_base
    txn = op: op, base: base, sent: false
    id = @_nextTxnId()
    @_txns[id] = txn
    @_txnQueue.push id
    # TODO: Raise event on creation of transaction
    txn.sent = @_send ['txn', [base, id, op...]]
    return id
  _removeTxn: (txnId) ->
    delete @_txns[txnId]
    txnQueue = @_txnQueue
    i = txnQueue.indexOf txnId
    if i > -1 then txnQueue.splice i, 1
  _lookup: (path, options = {}) ->
    obj = options.obj || @_data
    if path && path.split
      props = path.split '.'
      lookup obj, props, props.length, 0, '',
        @get, options.addPath, options.proto, options.onRef
    else
      obj: obj, path: ''
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

lookup = (obj, props, len, i, path, get, addPath, proto, onRef) ->
  prop = props[i++]

  # In speculative model operations, return a prototype referenced object
  if proto && !Object::isPrototypeOf(obj)
      obj = Object.create obj

  # Get the next object along the path
  next = obj[prop]
  if next == undefined
    if addPath
      # Create empty parent objects implied by the path
      next = obj[prop] = {}
    else
      # If an object can't be found, return null
      return obj: null

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

  if i < len
    lookup next, props, len, i, path, get, addPath, proto, onRef
  else
    obj: next, path: path, parent: obj, prop: prop