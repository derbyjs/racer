_ = require './util'

# Note that Model is written as an object constructor for testing purposes,
# but it is not intended to be instantiated multiple times in use. Therefore,
# all functions are simply defined in a closure, which would be inefficient
# if multiple model instantiations were created.

Model = module.exports = ->
  @_data = {}
  @_base = 0
  @_clientId = ''
  
  txnCount = 0
  nextTxnId = => @_clientId + '.' + txnCount++
  @_txns = txns = {}
  @_txnQueue = txnQueue = []
  @_addTxn = addTxn = (op) =>
    base = @_base
    txn = op: op, base: base, sent: false
    id = nextTxnId()
    txns[id] = txn
    txnQueue.push id
    # TODO: Raise event on creation of transaction
    txn.sent = send ['txn', [base, id, op...]]
    return id
  @_removeTxn = removeTxn = (txnId) ->
    delete txns[txnId]
    i = txnQueue.indexOf txnId
    if i > -1 then txnQueue.splice i, 1
  
  @get = get = (path) =>
    if len = txnQueue.length
      obj = Object.create @_data
      i = 0
      while i < len
        txn = txns[txnQueue[i++]]
        [method, args...] = txn.op
        args.push obj: obj, proto: true
        setters[method] args...
    else
      obj = @_data
    if path then lookup(path, obj: obj).obj else obj
  @set = (path, value) ->
    addTxn ['set', path, value]
  @delete = (path) ->
    addTxn ['del', path]
  @_setters = setters =
    set: (path, value, options = {}) ->
      options.addPath = true
      out = lookup path, options
      try
        out.parent[out.prop] = value
      catch err
        throw new Error 'Model set failed on: ' + path
    del: (path, options = {}) ->
      out = lookup path, options
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
  
  lookup = (path, options = {}) =>
    obj = options.obj || @_data
    if path && path.split
      props = path.split '.'
      _lookup obj, props, props.length, 0, '',
        options.addPath, options.proto, options.onRef
    else
      obj: obj, path: ''
  _lookup = (obj, props, len, i, path, addPath, proto, onRef) ->
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
      _lookup next, props, len, i, path, addPath, proto, onRef
    else
      obj: next, path: path, parent: obj, prop: prop
  
  socket = null
  @_setSocket = (_socket) ->
    socket = _socket
    _socket.connect()
    _socket.on 'message', onMessage
  send = (message) ->
    if socket
      socket.send message
      # TODO: Only return true if sent successfully
      return true
    else
      return false
  onMessage = (message) =>
    [type, content, meta] = JSON.parse message
    switch type
      when 'txn'
        [base, txnId, method, args...] = content
        setters[method] args...
        @_base = base
        removeTxn txnId
      when 'txnFail'
        removeTxn content
  
  @ref = (ref, key) ->
    if key? then $r: ref, $k: key else $r: ref
  
  return
