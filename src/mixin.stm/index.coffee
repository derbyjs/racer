transaction = require '../transaction'
pathParser = require '../pathParser'
Serializer = require '../Serializer'
specHelper = require '../specHelper'
mutators = require '../mutators'
AtomicModel = require './AtomicModel'
Async = require './Async'
Field = require '../mixin.ot/Field'

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
        delete @path

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
          self._applyTxn txn, !txn.emitted || self._clientId != transaction.clientId txn
      onTimeout: -> self._reqNewTxns()

    @_onTxn = (txn, num) =>
      # Copy meta properties onto this transaction if it matches one in the queue
      if queuedTxn = txns[transaction.id txn]
        txn.callback = queuedTxn.callback
        txn.emitted = queuedTxn.emitted
      txnApplier.add txn, num

    @_onTxnNum = (num) =>
      # Reset the number used to keep track of pending transactions
      txnApplier.setIndex (+num || 0) + 1
      txnApplier.clearPending()

    @_removeTxn = (txnId) =>
      delete txns[txnId]
      if ~(i = txnQueue.indexOf txnId) then txnQueue.splice i, 1
      @_cache.invalidateSpecModelCache()

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
    _addOpAsTxn: (method, path, args..., callback) ->
      # TODO: There is a lot of mutation of txn going on here. Clean this up.
      
      # Create a new transaction and add it to a local queue
      ver = @_getVer()
      id = @_nextTxnId()
      txn = transaction.create base: ver, id: id, method: method, args: [path, args...]

      @_queueTxn txn, callback

      unless path is null
        txnArgs = transaction.args txn
        path = txnArgs[0]
        # Apply a private transaction immediately and don't send it to the store
        if pathParser.isPrivate path
          @_cache.invalidateSpecModelCache()
          return @_applyTxn txn, !txn.emitted && !@_silent

        # Emit an event on creation of the transaction
        unless @_silent
          @emit method, txnArgs, true
          txn.emitted = true

      # Send it over Socket.IO or to the store on the server
      @_commit txn

    _applyTxn: (txn, forceEmit) ->
      ver = transaction.base txn
      local = 'callback' of txn
      if isCompound = transaction.isCompound txn
        ops = transaction.ops txn
        for op in ops
          @_applyMutation transaction.op, op, ver, forceEmit, local
      else
        {args} = @_applyMutation transaction, txn, ver, forceEmit, local

      @_removeTxn transaction.id txn

      if callback = txn.callback
        if isCompound
          callback null, transaction.ops(txn)...
        else
          callback null, args...
    
    _applyMutation: (extractor, mutation, appendArgs, forceEmit, local) ->
      method = extractor.method mutation
      return if method is 'get'
      args = extractor.args(mutation).concat appendArgs
      meta = @_adapter[method] args...
      # For converting array ref index api back to id api
      # TODO: Can this somehow be performed by the refs mixin?
      args[1] = _meta  if _meta = extractor.meta mutation

      # This marks an OT field as being non-speculative, so that OT ops can begin to be sent to the server
      # TODO Make this more comprehensive - if @involvesOtVal val
      # TODO Make sure this is not called during specModel, only on remote txns received
      # TODO See if we can move this into mixin.ot
      if method == 'set' && (!appendArgs[2] || !appendArgs[2].speculative) && @isOtVal(args[1])
        path = args[0]
        # TODO DRY this up. Appears, too, in mixin.ot/index
        unless field = @otFields[path]
          field = @otFields[path] = new Field @, path
          val = @_adapter.get path, @_specModel()[0]
          snapshot = field.snapshot = val?.$ot || str
        field.specTrigger true

      @emit method, args, local  if forceEmit
      return {args, meta}

    # TODO Will re-calculation of speculative model every time result
    #      in assignemnts to vars becoming stale?
    _specModel: ->
      cache = @_cache
      len = @_txnQueue.length
      if lastReplayedTxnId = cache.lastReplayedTxnId
        if cache.lastReplayedTxnId == @_txnQueue[len-1]
          return [cache.data, cache.path]
        data = cache.data
        replayFrom = 1 + @_txnQueue.indexOf cache.lastReplayedTxnId
      else
        replayFrom = 0

      adapter = @_adapter
      if len
        # Then generate a speculative model
        unless data
          # TODO adapter implementation details leaking in here
          # TODO Do not need Object.create here?
          data = cache.data = specHelper.create adapter._data

        appendArgs = [undefined, data, {speculative: true}]
        i = replayFrom
        while i < len
          # Apply each pending operation to the speculative model
          txn = @_txns[@_txnQueue[i++]]
          if transaction.isCompound txn
            ops = transaction.ops txn
            for op in ops
              @_applyMutation transaction.op, op, appendArgs
          else
            @_applyMutation transaction, txn, appendArgs
        
        cache.data = data
        cache.path = path = data.$path
        cache.lastReplayedTxnId = transaction.id txn
      return [data, path]

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
      val = @_adapter.get path, @_specModel()[0]
      if @isOtVal val
        return @getOT path, val.$ot
      return val

    set: (path, val, callback) ->
      @_addOpAsTxn 'set', path, val, callback
      return val
    
    setNull: (path, value, callback) ->
      obj = @get path
      return obj  if obj?
      @set path, value, callback

    # STM del
    del: (path, callback) ->
      @_addOpAsTxn 'del', path, callback

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
    
    push: (path, values..., callback) ->
      if 'function' != typeof callback && callback isnt undefined
        values.push callback
        callback = null
      @_addOpAsTxn 'push', path, values..., callback

    pop: (path, callback) ->
      @_addOpAsTxn 'pop', path, callback

    unshift: (path, values..., callback) ->
      if 'function' != typeof callback && callback isnt undefined
        values.push callback
        callback = null
      @_addOpAsTxn 'unshift', path, values..., callback

    shift: (path, callback) ->
      @_addOpAsTxn 'shift', path, callback

    insertAfter: (path, afterIndex, value, callback) ->
      @_addOpAsTxn 'insertAfter', path, afterIndex, value, callback

    insertBefore: (path, beforeIndex, value, callback) ->
      @_addOpAsTxn 'insertBefore', path, beforeIndex, value, callback

    remove: (path, start, howMany = 1, callback) ->
      # remove(path, start, callback)
      if typeof howMany is 'function'
        callback = howMany
        howMany = 1
      @_addOpAsTxn 'remove', path, start, howMany, callback

    splice: (path, startIndex, removeCount, newMembers..., callback) ->
      if 'function' != typeof callback && callback isnt undefined
        newMembers.push callback
        callback = null
      @_addOpAsTxn 'splice', path, startIndex, removeCount, newMembers..., callback

    move: (path, from, to, callback) ->
      @_addOpAsTxn 'move', path, from, to, callback
