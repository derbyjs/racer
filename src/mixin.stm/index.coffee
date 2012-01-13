transaction = require '../transaction'
pathParser = require '../pathParser'
Serializer = require '../Serializer'
{create: specCreate} = require '../specHelper'
AtomicModel = require './AtomicModel'
Async = require './Async'

stm = module.exports =
  static:
    # Timeout in milliseconds after which sent transactions will be resent
    _SEND_TIMEOUT: SEND_TIMEOUT = 10000
    # Interval in milliseconds to check timeouts for queued transactions
    _RESEND_INTERVAL: RESEND_INTERVAL = 2000

  init: ->
    # Context (i.e., this) is Model instance
    @_specCache =
      invalidate: ->
        delete @data
        delete @lastTxnId

    # The startId is the ID of the last Redis restart. This is sent along with
    # each versioned message from the Model so that the Store can map the model's
    # version number to the version number of the Stm in case of a Redis failure
    @_startId = ''

    # atomic models that have been generated stored by atomic transaction id.
    @_atomicModels = {}

    @_count =
      txn: 0
    @_txns = txns = {}
    @_txnQueue = txnQueue = []
    adapter = @_adapter
    self = this

    txnApplier = new Serializer
      withEach: (txn) ->
        if transaction.base(txn) > adapter.version
          isLocal = 'callback' of txn
          self._applyTxn txn, isLocal
      onTimeout: -> self._reqNewTxns()

    @_onTxn = (txn, num) ->
      # Copy meta properties onto this transaction if it matches one in the queue
      if queuedTxn = txns[transaction.id txn]
        txn.callback = queuedTxn.callback
        txn.emitted = queuedTxn.emitted
      txnApplier.add txn, num

    @_onTxnNum = (num) ->
      # Reset the number used to keep track of pending transactions
      txnApplier.setIndex (+num || 0) + 1
      txnApplier.clearPending()

    @_removeTxn = (txnId) ->
      delete txns[txnId]
      if ~(i = txnQueue.indexOf txnId) then txnQueue.splice i, 1
      self._specCache.invalidate()

    # The value of @_force is checked in @_addOpAsTxn. It can be used to create a
    # transaction without conflict detection, such as model.force.set
    @force = Object.create this, _force: value: true

    @async = new Async this

  setupSocket: (socket) ->
    {_adapter: adapter, _onTxn: onTxn, _removeTxn: removeTxn, _txns: txns, _txnQueue: txnQueue} = self = this
    
    @_commit = commit = (txn) ->
      return if txn.isPrivate || !socket.socket.connected
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn, self._startId

    # STM Callbacks
    socket.on 'txn', onTxn

    socket.on 'txnNum', @_onTxnNum

    socket.on 'txnOk', (txnId, base, num) ->
      return unless txn = txns[txnId]
      transaction.base txn, base
      onTxn txn, num

    socket.on 'txnErr', (err, txnId) ->
      txn = txns[txnId]
      if txn && (callback = txn.callback)
        if transaction.isCompound txn
          callbackArgs = transaction.ops txn
        else
          callbackArgs = transaction.args(txn).slice 0
        callbackArgs.unshift err
        callback callbackArgs...
      removeTxn txnId
    # Request any transactions that may have been missed
    @_reqNewTxns = -> socket.emit 'txnsSince', _adapter.version + 1, self._startId

    resendInterval = null
    resend = ->
      now = +new Date
      for id in txnQueue
        txn = txns[id]
        return if !txn || txn.timeout > now
        commit txn

    socket.on 'connect', ->
      # Resend all transactions in the queue
      for id in txnQueue
        commit txns[id]
      # Set an interval to check for transactions that have been in the queue
      # for too long and resend them
      resendInterval = setInterval resend, RESEND_INTERVAL unless resendInterval
  
    socket.on 'disconnect', ->
      # Stop resending transactions while disconnected
      clearInterval resendInterval if resendInterval
      resendInterval = null

  proto:
    ## Socket.io communication ##
    _commit: ->
    _reqNewTxns: ->


    ## Transaction handling ##
    
    _nextTxnId: -> @_clientId + '.' + @_count.txn++

    _queueTxn: (txn, callback) ->
      txn.callback = callback
      id = transaction.id txn
      @_txns[id] = txn
      @_txnQueue.push id

    _getVer: -> if @_force then null else @_adapter.version

    _addOpAsTxn: (method, args, callback) ->
      # Refs may mutate the args in its 'beforeTxn' handler
      @emit 'beforeTxn', method, args

      return unless (path = args[0])?

      # Create a new transaction
      base = @_getVer()
      id = @_nextTxnId()
      txn = transaction.create {base, id, method, args}
      txn.isPrivate = pathParser.isPrivate path

      @_queueTxn txn, callback
      out = @_specModel().$out

      unless @_silent
        # Clone the args, so that they can be modified before being emitted
        # without affecting the txn args
        args = args.slice()
        # Emit an event immediately on creation of the transaction
        @emit method, args, out, true, @_pass
      txn.emitted = true

      # Send it over Socket.IO or to the store on the server
      @_commit txn
      return out

    _applyTxn: (txn, isLocal) ->
      @_removeTxn transaction.id txn

      data = @_adapter._data
      doEmit = !(txn.emitted || @_silent)
      ver = transaction.base txn
      if isCompound = transaction.isCompound txn
        ops = transaction.ops txn
        for op in ops
          @_applyMutation transaction.op, op, ver, data, doEmit, isLocal
      else
        out = @_applyMutation transaction, txn, ver, data, doEmit, isLocal

      if callback = txn.callback
        if isCompound
          callback null, transaction.ops(txn)...
        else
          callback null, transaction.args(txn)..., out
      return out

    _applyMutation: (extractor, mutation, ver, data, doEmit, isLocal) ->
      method = extractor.method mutation
      return if method is 'get'
      args = extractor.args mutation
      out = @_adapter[method] args..., ver, data
      @emit method + 'Post', args, ver
      @emit method, args, out, isLocal, @_pass  if doEmit
      return out
    
    _specModel: ->
      txns = @_txns
      txnQueue = @_txnQueue
      while (txn = txns[txnQueue[0]]) && txn.isPrivate
        out = @_applyTxn txn, true

      unless len = txnQueue.length
        data = @_adapter._data
        data.$out = out
        return data

      cache = @_specCache
      if lastTxnId = cache.lastTxnId
        return cache.data  if cache.lastTxnId == txnQueue[len - 1]
        data = cache.data
        replayFrom = 1 + txnQueue.indexOf cache.lastTxnId
      else
        replayFrom = 0

      unless data
        # Generate a speculative model
        data = cache.data = specCreate @_adapter._data

      i = replayFrom
      while i < len
        # Apply each pending operation to the speculative model
        txn = txns[txnQueue[i++]]
        if transaction.isCompound txn
          ops = transaction.ops txn
          for op in ops
            @_applyMutation transaction.op, op, null, data
        else
          out = @_applyMutation transaction, txn, null, data

      cache.data = data
      cache.lastTxnId = transaction.id txn

      data.$out = out
      return data

    # TODO
    snapshot: ->
      model = new AtomicModel @_nextTxnId(), this
      model._adapter = adapter.snapshot()
      return model

    atomic: (block, callback) ->
      model = new AtomicModel @_nextTxnId(), this
      @_atomicModels[model.id] = model
      self = this
      commit = (_callback) ->
        model.commit (err) ->
          delete self._atomicModels[model.id] unless err
          _callback.apply null, arguments if _callback ||= callback
      abort = ->
      retry = ->

      if block.length == 1
        block model
        commit callback
      else if block.length == 2
        block model, commit
      else if block.length == 3
        block model, commit, abort
      else if block.length == 4
        block model, commit, abort, retry


  ## Data accessor and mutator methods ##

  accessors:

    get:
      type: 'basic'
      fn: (path) ->
        @_adapter.get path, @_specModel()

  mutators:

    set:
      type: 'basic'
      fn: (path, val, callback) ->
        @_addOpAsTxn 'set', [path, val], callback

    del:
      type: 'basic'
      fn: (path, callback) ->
        @_addOpAsTxn 'del', [path], callback

    setNull:
      type: 'compound'
      fn: (path, value, callback) ->
        obj = @get path
        return obj  if obj?
        @set path, value, callback

    incr:
      type: 'compound'
      fn: (path, byNum, callback) ->
        # incr(path, callback)
        if typeof byNum is 'function'
          callback = byNum
          byNum = 1
        # incr(path)
        else if typeof byNum isnt 'number'
          byNum = 1
        value = (@get(path) || 0) + byNum
        @set path, value, callback
        return value

    push:
      type: 'array'
      insertArgs: 1
      fn: (args..., callback) ->
        if typeof callback isnt 'function'
          args.push callback
          callback = null
        @_addOpAsTxn 'push', args, callback

    unshift:
      type: 'array'
      insertArgs: 1
      fn: (args..., callback) ->
        if typeof callback isnt 'function'
          args.push callback
          callback = null
        @_addOpAsTxn 'unshift', args, callback

    pop:
      type: 'array'
      fn: (path, callback) ->
        @_addOpAsTxn 'pop', [path], callback

    shift:
      type: 'array'
      fn: (path, callback) ->
        @_addOpAsTxn 'shift', [path], callback

    insert:
      type: 'array'
      indexArgs: [1]
      insertArgs: 2
      fn: (args..., callback) ->
        if typeof callback isnt 'function'
          args.push callback
          callback = null
        @_addOpAsTxn 'insert', args, callback

    remove:
      type: 'array'
      indexArgs: [1]
      fn: (path, start, howMany, callback) ->
        # remove(path, start, callback)
        if typeof howMany is 'function'
          callback = howMany
          howMany = 1
        # remove(path, start)
        else if typeof howMany isnt 'number'
          howMany = 1
        @_addOpAsTxn 'remove', [path, start, howMany], callback

    move:
      type: 'array'
      indexArgs: [1, 2]
      fn: (path, from, to, callback) ->
        @_addOpAsTxn 'move', [path, from, to], callback
