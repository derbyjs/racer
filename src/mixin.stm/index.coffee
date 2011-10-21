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
    @_cache =
      invalidateSpecModelCache: ->
        delete @data
        delete @lastReplayedTxnId

    # The startId is the ID of the last Redis restart. This is sent along with
    # each versioned message from the Model so that the Store can map the model's
    # version number to the version number of the Stm in case of a Redis failure
    @_startId = ''

    # atomic models that have been generated stored by atomic transaction id.
    @_atomicModels = {}

    @_txnCount = 0
    @_txns = txns = {}
    @_txnQueue = txnQueue = []
    adapter = @_adapter
    self = this

    txnApplier = new Serializer
      withEach: (txn) ->
        if transaction.base(txn) > adapter.version()
          self._applyTxn txn
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
      self._cache.invalidateSpecModelCache()

    # The value of @_force is checked in @_addOpAsTxn. It can be used to create a
    # transaction without conflict detection, such as model.force.set
    @force = Object.create this, _force: value: true

    @async = new Async this

  setupSocket: (socket) ->
    {_adapter, _txns, _txnQueue, _onTxn, _removeTxn} = self = this
    
    @_commit = commit = (txn) ->
      return unless socket.socket.connected
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn, self._startId

    # STM Callbacks
    socket.on 'txn', _onTxn

    socket.on 'txnNum', @_onTxnNum

    socket.on 'txnOk', (txnId, base, num) ->
      return unless txn = _txns[txnId]
      transaction.base txn, base
      _onTxn txn, num

    socket.on 'txnErr', (err, txnId) ->
      txn = _txns[txnId]
      if txn && (callback = txn.callback)
        if transaction.isCompound txn
          callbackArgs = transaction.ops txn
        else
          callbackArgs = transaction.args(txn).slice 0
        callbackArgs.unshift err
        callback callbackArgs...
      _removeTxn txnId
    # Request any transactions that may have been missed
    @_reqNewTxns = -> socket.emit 'txnsSince', _adapter.version() + 1, self._startId

    resendInterval = null
    resend = ->
      now = +new Date
      for id in _txnQueue
        txn = _txns[id]
        return if txn.timeout > now
        commit txn

    socket.on 'connect', ->
      # Resend all transactions in the queue
      for id in _txnQueue
        commit _txns[id]
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
    
    _nextTxnId: -> @_clientId + '.' + @_txnCount++

    _queueTxn: (txn, callback) ->
      txn.callback = callback
      id = transaction.id txn
      @_txns[id] = txn
      @_txnQueue.push id

    _getVer: -> if @_force then null else @_adapter.version()

    # This method is overwritten by the refs mixin
    # TODO: All of this code is duplicated in refs right now. DRY
    _addOpAsTxn: (method, args, callback) ->
      # Refs may mutate the args in its 'beforeTxn' handler
      @emit 'beforeTxn', method, args

      # Create a new transaction and add it to a local queue
      base = @_getVer()
      id = @_nextTxnId()
      meta = args.meta
      txn = transaction.create {base, id, method, args, meta}
      @_queueTxn txn, callback

      if (path = args[0])?
        # Apply a private transaction immediately and don't send it to the store
        if pathParser.isPrivate path
          # @_cache.invalidateSpecModelCache()
          return @_applyTxn txn

        # Version must be null, since this is speculative
        @emit method + 'Post', args, null, null, meta
        # Emit an event on creation of the transaction
        @emit method, args, true  unless @_silent
        txn.emitted = true

      # Send it over Socket.IO or to the store on the server
      @_commit txn

    _applyTxn: (txn) ->
      data = @_adapter._data
      doEmit = !(txn.emitted || @_silent)
      isLocal = 'callback' of txn
      ver = transaction.base txn
      if isCompound = transaction.isCompound txn
        ops = transaction.ops txn
        for op in ops
          @_applyMutation transaction.op, op, ver, data, doEmit, isLocal
      else
        args = @_applyMutation transaction, txn, ver, data, doEmit, isLocal

      @_removeTxn transaction.id txn

      if callback = txn.callback
        if isCompound
          callback null, transaction.ops(txn)...
        else
          callback null, args...
    
    _applyMutation: (extractor, mutation, ver, data, doEmit, isLocal) ->
      method = extractor.method mutation
      return if method is 'get'
      args = extractor.args mutation
      meta = extractor.meta mutation
      @emit method + 'Pre', args, ver, data, meta
      @_adapter[method] args..., ver, data
      @emit method + 'Post', args, ver, data, meta
      @emit method, args, isLocal, meta  if doEmit
      return args

    _specModel: ->
      cache = @_cache
      len = @_txnQueue.length
      if lastReplayedTxnId = cache.lastReplayedTxnId
        return cache.data  if cache.lastReplayedTxnId == @_txnQueue[len - 1]
        data = cache.data
        replayFrom = 1 + @_txnQueue.indexOf cache.lastReplayedTxnId
      else
        replayFrom = 0

      if len
        # Then generate a speculative model
        unless data
          data = cache.data = specCreate @_adapter._data

        i = replayFrom
        while i < len
          # Apply each pending operation to the speculative model
          txn = @_txns[@_txnQueue[i++]]
          if transaction.isCompound txn
            ops = transaction.ops txn
            for op in ops
              @_applyMutation transaction.op, op, null, data
          else
            @_applyMutation transaction, txn, null, data
        
        cache.data = data
        cache.lastReplayedTxnId = transaction.id txn
      return data || @_adapter._data

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
    get: (path) ->
      return @_adapter.get path, @_specModel()

    set: (path, val, callback) ->
      @_addOpAsTxn 'set', [path, val], callback
      return val
    
    setNull: (path, value, callback) ->
      obj = @get path
      return obj  if obj?
      @set path, value, callback

    del: (path, callback) ->
      @_addOpAsTxn 'del', [path], callback

    incr: (path, byNum, callback) ->
      # incr(path, callback)
      if typeof byNum is 'function'
        callback = byNum
        byNum = 1
      # incr(path)
      else if typeof byNum isnt 'number'
        byNum = 1
      @set path, (@get(path) || 0) + byNum, callback

    ## Array methods ##

    push: (args..., callback) ->
      if typeof callback isnt 'function'
        args.push callback
        callback = null
      @_addOpAsTxn 'push', args, callback

    unshift: (args..., callback) ->
      if typeof callback isnt 'function'
        args.push callback
        callback = null
      @_addOpAsTxn 'unshift', args, callback

    splice: (args..., callback) ->
      if typeof callback isnt 'function'
        args.push callback
        callback = null
      @_addOpAsTxn 'splice', args, callback

    pop: (path, callback) ->
      @_addOpAsTxn 'pop', [path], callback

    shift: (path, callback) ->
      @_addOpAsTxn 'shift', [path], callback

    insertAfter: (path, afterIndex, value, callback) ->
      @_addOpAsTxn 'insertAfter', [path, afterIndex, value], callback

    insertBefore: (path, beforeIndex, value, callback) ->
      @_addOpAsTxn 'insertBefore', [path, beforeIndex, value], callback

    remove: (path, start, howMany, callback) ->
      # remove(path, start, callback)
      if typeof howMany is 'function'
        callback = howMany
        howMany = 1
      # remove(path, start)
      else if typeof howMany isnt 'number'
        howMany = 1
      @_addOpAsTxn 'remove', [path, start, howMany], callback

    move: (path, from, to, callback) ->
      @_addOpAsTxn 'move', [path, from, to], callback
