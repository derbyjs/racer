_ = require './util'

Model = module.exports = ->
  self = this
  self._data = {}
  self._base = 0
  
  self._clientId = ''
  txnCount = 0
  nextTxnId = -> self._clientId + '.' + txnCount++
  
  txns = self._txns = {}
  txnQueue = self._txnQueue = []
  addTxn = (op) ->
    base = self._base
    txn = op: op, base: base, sent: false
    id = nextTxnId()
    txns[id] = txn
    txnQueue.push id
    # TODO: Raise event on creation of transaction
    txn.sent = self._send ['txn', [base, id, op...]]
    return id
    
  _lookup = (data, path, options = {}) ->
    if path && path.split
      props = path.split '.'
      lookup data, props, props.length, 0, '',
        self.get, options.addPath, options.onRef
    else
      obj: data, path: ''
  
  self.get = (path) ->
    if i = txnQueue.length
      data = Object.create self._data
      while txnId = txnQueue[--i]
        txn = txns[txnId]
        [method, args...] = txn.op
        args.push data
        setters[method].apply self, args
    else
      data = self._data
    _lookup(data, path).obj
  
  setters = self._setters =
    set: (path, value, data = self._data) ->
      out = _lookup data, path, addPath: true
      try
        out.parent[out.prop] = value
      catch err
        throw new Error 'Model set failed on: ' + path
    del: (path, data = self._data) ->
      out = _lookup data, path
      try
        delete out.parent[out.prop]
      catch err
        throw new Error 'Model delete failed on: ' + path
  
  self.set = (path, value) ->
    addTxn ['set', path, value]
  self.delete = (path) ->
    addTxn ['del', path]
    
  if _.onServer
    self._send = (message) ->
      if self._socket then self._socket.broadcast message
    self._initSocket = (socket) ->
      socket.on 'connection', (client) ->
        client.on 'message', (message) ->
          [method, path, args] = JSON.parse message
          # TODO: Handle message from client
  else
    self._send = (message) ->
      if self._socket
        self._socket.send message
        # TODO: Only return true if sent successfully
        return true
      else
        return false
    self._initSocket = (socket) ->
      socket.connect()
      socket.on 'message', (message) ->
        [type, content, meta] = JSON.parse message
        if type is 'txn'
          [base, txnId, method, args...] = content
          setters[method].apply self, args
          self._base = base
          delete txns[txnId]
          i = txnQueue.indexOf txnId
          if i > -1 then txnQueue.splice i, 1
  return

Model:: =
  _setSocket: (socket) ->
    this._socket = socket
    this._initSocket socket
  ref: (ref, key) ->
    if key? then $r: ref, $k: key else $r: ref

lookup = (obj, props, len, i, path, get, addPath, onRef) ->
  prop = props[i++]
  
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
    lookup next, props, len, i, path, get, addPath, onRef
  else
    obj: next, path: path, parent: obj, prop: prop