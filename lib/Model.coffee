_ = require('./util')

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
    self._send(['txn', [base, id, op...]])
    return id
    
  _lookup = (path, options = {}) ->
    if path && path.split
      props = path.split('.')
      lookup self._data, props, props.length, 0, '',
        self.get, options.isSet, options.onRef
    else
      obj: self._data, path: ''
  
  self.get = (path) -> _lookup(path).obj
  
  setters = self._setters =
    set: (path, value) ->
      out = _lookup path, isSet: true
      try
        out.return = out.obj[out.prop] = value
      catch err
        throw new Error 'Model set failed on: ' + path
      return out
  
  self.set = (path, value) ->
    addTxn ['set', path, value]
    
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
      if self._socket then self._socket.send message
    self._initSocket = (socket) ->
      socket.connect()
      socket.on 'message', (message) ->
        [type, content, meta] = JSON.parse message
        if type is 'txn'
          [base, txnId, method, args...] = content
          setters[method].apply self, args
          self._base = base
  return

Model.prototype = {
  _setSocket: (socket) ->
    this._socket = socket
    this._initSocket socket
  ref: (ref, key) ->
    if key? then $r: ref, $k: key else $r: ref
}

lookup = (obj, props, len, i, path, get, isSet, onRef) ->
  prop = props[i++]
  
  # Get the next object along the path
  next = obj[prop]
  if next == undefined
    if isSet
      # In set, create empty parent objects implied by the path
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
    lookup next, props, len, i, path, get, isSet, onRef
  else
    if isSet then obj: obj, prop: prop, path: path else obj: next, path: path