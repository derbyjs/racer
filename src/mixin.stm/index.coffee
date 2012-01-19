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
    @_specCache = specCache =
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
      id: 0
    @_txns = txns = {}
    @_txnQueue = txnQueue = []

    @_removeTxn = (txnId) ->
      delete txns[txnId]
      if ~(i = txnQueue.indexOf txnId) then txnQueue.splice i, 1
      specCache.invalidate()

    self = this
    adapter = @_adapter
    @_onTxn = (txn) ->
      # Copy meta properties onto this transaction if it matches one in the queue
      if queuedTxn = txns[transaction.id txn]
        txn.callback = queuedTxn.callback
        txn.emitted = queuedTxn.emitted

      if transaction.base(txn) > adapter.version
        isLocal = 'callback' of txn
        self._applyTxn txn, isLocal

    # The value of @_force is checked in @_addOpAsTxn. It can be used to create a
    # transaction without conflict detection, such as model.force.set
    @force = Object.create this, _force: value: true

    @async = new Async this

  setupSocket: (socket) ->
    self = this
    adapter = @_adapter
    txns = @_txns
    txnQueue = @_txnQueue
    removeTxn = @_removeTxn
    onTxn = @_onTxn

    notReady = true
    @_commit = commit = (txn) ->
      return if txn.isPrivate || notReady
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn, self._startId

    txnApplier = new Serializer
      withEach: onTxn
      onTimeout: newTxns = ->
        socket.emit 'txnsSince', adapter.version + 1, self._startId, (newTxns, num) ->

          # Apply any missed transactions first
          for txn in newTxns
            onTxn txn

          # Reset the number used to keep track of pending transactions
          txnApplier.clearPending()
          txnApplier.setIndex num + 1
          notReady = false

          # Resend all transactions in the queue
          for id in txnQueue
            commit txns[id]

    socket.on 'txn', (txn, num) ->
      txnApplier.add txn, num

    socket.on 'txnOk', (txnId, base, num) ->
      return unless txn = txns[txnId]
      transaction.base txn, base
      txnApplier.add txn, num

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

    resendInterval = null
    resend = ->
      now = +new Date
      for id in txnQueue
        txn = txns[id]
        return if !txn || txn.timeout > now
        commit txn

    socket.on 'connect', ->
      newTxns()
      # Set an interval to check for transactions that have been in the queue
      # for too long and resend them
      resendInterval = setInterval resend, RESEND_INTERVAL unless resendInterval

    socket.on 'disconnect', ->
      notReady = true
      # Stop resending transactions while disconnected
      clearInterval resendInterval if resendInterval
      resendInterval = null

  proto:
    id: -> '$_' + @_clientId + '_' + (@_count.id++).toString 36

    ## Socket.io communication ##
    _commit: ->

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
      doEmit = !txn.emitted
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
        if at = @_at
          path = if path then at + '.' + path else at
        @_adapter.get path, @_specModel()

  mutators:

    set:
      type: 'basic'
      fn: (path, value, callback) ->
        if at = @_at
          len = arguments.length
          path = if len is 1 || len is 2 && typeof value is 'function'
            callback = value
            value = path
            at
          else
            at + '.' + path
        @_addOpAsTxn 'set', [path, value], callback

    del:
      type: 'basic'
      fn: (path, callback) ->
        if at = @_at
          path = if typeof path is 'string'
            at + '.' + path
          else
            callback = path
            at
        @_addOpAsTxn 'del', [path], callback

    setNull:
      type: 'compound'
      fn: (path, value, callback) ->
        len = arguments.length
        obj = if @_at && len is 1 || len is 2 && typeof value is 'function'
          @get()
        else
          @get path
        return obj  if obj?

        if len is 1
          return @set path
        else if len is 2
          return @set path, value
        else
          return @set path, value, callback

    incr:
      type: 'compound'
      fn: (path, byNum, callback) ->
        if typeof path isnt 'string'
          callback = byNum
          byNum = path
          path = ''

        if typeof byNum is 'function'
          callback = byNum
          byNum = 1
        else if typeof byNum isnt 'number'
          byNum = 1
        value = (@get(path) || 0) + byNum

        if path
          @set path, value, callback
          return value

        if callback
          @set value, callback
        else
          @set value
        return value

    push:
      type: 'array'
      insertArgs: 1
      fn: (args...) ->
        if at = @_at
          if typeof (path = args[0]) is 'string' && typeof @get() is 'object'
            args[0] = at + '.' + path
          else
            args.unshift at

        if typeof args[args.length - 1] is 'function'
          callback = args.pop()
        @_addOpAsTxn 'push', args, callback

    unshift:
      type: 'array'
      insertArgs: 1
      fn: (args...) ->
        if at = @_at
          if typeof (path = args[0]) is 'string' && typeof @get() is 'object'
            args[0] = at + '.' + path
          else
            args.unshift at

        if typeof args[args.length - 1] is 'function'
          callback = args.pop()
        @_addOpAsTxn 'unshift', args, callback

    insert:
      type: 'array'
      indexArgs: [1]
      insertArgs: 2
      fn: (args...) ->
        if at = @_at
          # isNaN will be false for index values in a string like '3'
          if typeof (path = args[0]) is 'string' && isNaN path
            args[0] = at + '.' + path
          else
            args.unshift at
        if match = /^(.*)\.(\d+)$/.exec args[0]
          # Use the index from the path if it ends in an index segment
          args[0] = match[1]
          args.splice 1, 0, match[2]

        if typeof args[args.length - 1] is 'function'
          callback = args.pop()
        @_addOpAsTxn 'insert', args, callback

    pop:
      type: 'array'
      fn: (path, callback) ->
        if at = @_at
          path = if typeof path is 'string'
            at + '.' + path
          else
            callback = path
            at
        @_addOpAsTxn 'pop', [path], callback

    shift:
      type: 'array'
      fn: (path, callback) ->
        if at = @_at
          path = if typeof path is 'string'
            at + '.' + path
          else
            callback = path
            at
        @_addOpAsTxn 'shift', [path], callback

    remove:
      type: 'array'
      indexArgs: [1]
      fn: (path, start, howMany, callback) ->
        if at = @_at
          # isNaN will be false for index values in a string like '3'
          path = if typeof path is 'string' && isNaN path
            at + '.' + path
          else
            callback = howMany
            howMany = start
            start = path
            at
        if match = /^(.*)\.(\d+)$/.exec path
          # Use the index from the path if it ends in an index segment
          callback = howMany
          howMany = start
          start = match[2]
          path = match[1]

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
        if at = @_at
          # isNaN will be false for index values in a string like '3'
          path = if typeof path is 'string' && isNaN path
            at + '.' + path
          else
            callback = to
            to = from
            from = path
            at
        if match = /^(.*)\.(\d+)$/.exec path
          # Use the index from the path if it ends in an index segment
          callback = to
          to = from
          from = match[2]
          path = match[1]

        @_addOpAsTxn 'move', [path, from, to], callback
