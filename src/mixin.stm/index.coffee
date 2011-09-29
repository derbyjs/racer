transaction = require '../transaction'
pathParser = require '../pathParser'
AtomicModel = require '../AtomicModel'
TxnApplier = require '../TxnApplier'
specHelper = require '../specHelper'
mutators = require '../mutators'

stm = module.exports =
  static:
    # Timeout in milliseconds after which sent transactions will be resent
    _SEND_TIMEOUT: SEND_TIMEOUT = 10000
    # Interval in milliseconds to check timeouts for queued transactions
    _RESEND_INTERVAL: RESEND_INTERVAL = 2000

    genAddOpAsTxn: genAddOpAsTxn = (options) ->
      {callback: hasCallback, getVer, commit} = options
      # TODO There is a lot of mutation of txn going on here.
      #      Clean this up.
      return (method, path, args..., callback) ->
        if !hasCallback && callback isnt undefined
          args.push callback
          callback = undefined
        refHelper = @_refHelper
        model = @

        # just in case we did atomicModel.get()
        getWorld = null == path

        unless getWorld
          # Transform args if path represents an array ref
          if {$r, $k} = refHelper.isArrayRef path, @_specModel()[0]
            [firstArgs, members] =
              (mutators.basic[method] || mutators.array[method]).splitArgs args
            members = members.map (member) ->
              return member if refHelper.isRefObj member
              # MUTATION
              model.set $r + '.' + member.id, member
              return {$r, $k: member.id.toString()}
            args = firstArgs.concat members

          # Convert id args to index args if we happen to be
          # using array ref mutator id api
          if mutators.array[method]?.indexesInArgs
            idAsIndex = refHelper.arrRefIndex args[0], path, @_specModel()[0]
        
        # Create a new transaction and add it to a local queue
        ver = getVer.call model
        id = @_nextTxnId()
        txn = transaction.create base: ver, id: id, method: method, args: [path, args...]
        # NOTE: This converts the transaction
        unless getWorld
          txn = refHelper.dereferenceTxn txn, @_specModel()[0]

        @_queueTxn txn, callback

        unless getWorld
          txnArgs = transaction.args txn
          path = txnArgs[0]
          # Apply a private transaction immediately and don't send it to the store
          if pathParser.isPrivate path
            @_cache.invalidateSpecModelCache()
            return @_applyTxn txn, !txn.emitted && !@_silent

          if idAsIndex isnt undefined
            meta = txnArgs[1] # txnArgs[1] has form {id: id}
            meta.index = idAsIndex
            transaction.meta txn, meta

          # Emit an event on creation of the transaction
          unless @_silent
            @emit method, txnArgs, true
            txn.emitted = true

          txnArgs[1] = idAsIndex if idAsIndex isnt undefined

        # Send it over Socket.IO or to the store on the server
        @_commit txn if commit

  init: ->
    # Context (i.e., this) is Model instance
    @_cache =
      invalidateSpecModelCache: ->
        delete @obj
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

    txnApplier = new TxnApplier
      applyTxn: (txn) ->
        if transaction.base(txn) > adapter.ver
          self._applyTxn txn, !txn.emitted && @_clientId != transaction.clientId txn
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


  setupSocket: (socket) ->
    self = this
    adapter = @_adapter
    txns = @_txns
    txnQueue = @_txnQueue
    onTxn = @_onTxn
    removeTxn = @_removeTxn
    
    @_commit = commit = (txn) ->
      return unless socket.socket.connected
      txn.timeout = +new Date + SEND_TIMEOUT
      socket.emit 'txn', txn, self._startId

    # STM Callbacks
    socket.on 'txn', onTxn

    socket.on 'txnNum', @_onTxnNum

    socket.on 'txnOk', (txnId, base, num) ->
      if txn = txns[txnId]
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
    @_reqNewTxns = -> socket.emit 'txnsSince', adapter.ver + 1, self._startId

    clientId = @_clientId
    storeSubs = @_storeSubs
    resendInterval = null
    resend = ->
      now = +new Date
      for id in txnQueue
        txn = txns[id]
        return if txn.timeout > now
        commit txn
    
    socket.on 'connect', ->
      # Establish subscriptions upon connecting and get any transactions
      # that may have been missed
      socket.emit 'sub', clientId, storeSubs, adapter.ver, self._startId
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
    
    _nextTxnId: -> @_clientId + '.' + @_txnCount++

    _queueTxn: (txn, callback) ->
      txn.callback = callback if callback
      id = transaction.id txn
      @_txns[id] = txn
      @_txnQueue.push id

    _addOpAsTxn: genAddOpAsTxn
      callback: true
      getVer: -> if @_force then null else @_adapter.ver
      commit: true
    
    _applyTxn: (txn, forceEmit) ->
      ver = transaction.base txn
      if isCompound = transaction.isCompound txn
        ops = transaction.ops txn
        for op in ops
          @_applyMutation transaction.op, op,
            ver: ver
            forceEmit: forceEmit
            txnHasCallback: 'callback' of txn
      else
        args = @_applyMutation transaction, txn,
          ver: ver
          forceEmit: forceEmit
          txnHasCallback: 'callback' of txn

      @_removeTxn transaction.id txn

      if callback = txn.callback
        if isCompound
          callback null, transaction.ops(txn)...
        else
          callback null, args...
    
    _applyMutation: (extractor, mutation, {obj, proto, ver, forceEmit, txnHasCallback}) ->
      adapter = @_adapter
      method = extractor.method mutation
      return if method == 'get'
      args = extractor.args(mutation).slice 0
      if proto
        args.push undefined, obj, {proto, returnMeta: true}
      else
        args.push ver
      meta = adapter[method] args...
      # For converting array ref index api back to id api
      args[1] = meta if meta = extractor.meta mutation

      if forceEmit
        # Third argument is true for locally created transactions
        @emit method, args, txnHasCallback

      return if proto then meta else args

    # TODO Will re-calculation of speculative model every time result
    #      in assignemnts to vars becoming stale?
    _specModel: ->
      cache = @_cache
      len = @_txnQueue.length
      if lastReplayedTxnId = cache.lastReplayedTxnId
        if cache.lastReplayedTxnId == @_txnQueue[len-1]
          return [cache.obj, cache.path]
        obj = cache.obj
        replayFrom = 1 + @_txnQueue.indexOf cache.lastReplayedTxnId
      else
        replayFrom = 0

      adapter = @_adapter
      if len
        # Then generate a speculative model
        unless obj
          # TODO adapter implementation details leaking in here
          # TODO Do not need Object.create here?
          obj = cache.obj = specHelper.create adapter._data

        i = replayFrom
        while i < len
          # Apply each pending operation to the speculative model
          txn = @_txns[@_txnQueue[i++]]
          if transaction.isCompound txn
            ops = transaction.ops txn
            for op in ops
              meta = @_applyMutation transaction.op, op, {obj, proto: true}
          else
            meta = @_applyMutation transaction, txn, {obj, proto: true}
          path = meta.path if meta
        cache.obj = obj
        cache.path = path
        cache.lastReplayedTxnId = transaction.id txn
      return [obj, path]

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
      {val, ver} = @_adapter.get path, @_specModel()[0]
      return val

    set: (path, val, callback) ->
      if v = val.$ot
        # TODO Only allow val to appear to user only
        #      if/once the path is in the permanent, not
        #      speculative model
        # TODO Eval path to refs
        adapter.set path, val, ver
        return v
      @_addOpAsTxn 'set', path, val, callback
      return val
    
    setNull: (path, value, callback) ->
      obj = @get path
      return obj  if `obj != null`
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

