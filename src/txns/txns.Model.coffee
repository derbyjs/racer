Memory = require '../Memory'
Promise = require '../Promise'
Serializer = require '../Serializer'
transaction = require '../transaction'
{isPrivate} = require '../path'
{create: specCreate} = require '../speculative'
# AtomicModel = require './AtomicModel'
{mergeTxn} = require './diff'
arrayMutator = null

module.exports =
  type: 'Model'

  static:
    # Timeout in milliseconds after which sent transactions will be resent
    SEND_TIMEOUT: SEND_TIMEOUT = 10000
    # Interval in milliseconds to check timeouts for queued transactions
    RESEND_INTERVAL: RESEND_INTERVAL = 2000

  events:

    mixin: (Model) ->
      {arrayMutator} = Model

    init: (model) ->
      # Add a promise that is checked at bundle time to make sure all transactions
      # have been committed on the server before a model gets serialized
      if bundlePromises = model._bundlePromises
        bundlePromises.push model._txnsPromise = new Promise

      model._specCache = specCache =
        invalidate: ->
          delete @data
          delete @lastTxnId

      # TODO: Finish implementation of atomic transactions
      # atomic models that have been generated stored by atomic transaction id.
      # model._atomicModels = {}

      model._count.txn = 0
      model._txns = txns = {}  # transaction id -> transaction
      model._txnQueue = txnQueue = []  # [transactionIds...]

      model._removeTxn = (txnId) ->
        delete txns[txnId]
        if ~(i = txnQueue.indexOf txnId)
          txnQueue.splice i, 1
          specCache.invalidate()
        return

      # TODO Add client-side filtering for incoming data on
      # no-longer-subscribed-to channels. This alleviates race condition of
      # receiving a message on a channel the client just unsubscribed to

      memory = model._memory
      # Used for diffing array operations in order emitted vs order applied
      before = new Memory
      after = new Memory
      model._onTxn = (txn) ->
        return unless txn?

        # Copy meta properties onto this transaction if it matches one in the queue
        if txnQ = txns[transaction.getId txn]
          txn.callback = txnQ.callback
          txn.emitted = txnQ.emitted

        unless isLocal = 'callback' of txn
          mergeTxn txn, txns, txnQueue, arrayMutator, memory, before, after

        ver = transaction.getVer txn
        if ver > memory.version || ver == -1
          model._applyTxn txn, isLocal
        return

    bundle: (model) ->
      # Get the speculative model, which will apply any pending private path
      # transactions that may get stuck in the first position of the queue
      model._specModel()
      # Wait for all pending transactions to complete before returning
      if model._txnQueue.length
        model.__removeTxn = model._removeTxn
        model._removeTxn = (txnId) ->
          model.__removeTxn txnId
          model._specModel()
          return if model._txnQueue.length
          model._txnsPromise.resolve()
        return
      model._txnsPromise.resolve()

    socket: (model, socket) ->
      memory = model._memory
      txns = model._txns
      txnQueue = model._txnQueue
      removeTxn = model._removeTxn
      onTxn = model._onTxn

      # The startId is the ID of the last Journal restart. This is sent along with
      # each versioned message from the Model so that the Store can map the model's
      # version number to the version number of the Journal in case of a failure

      notReady = true
      resendInterval = null
      resend = ->
        now = +new Date
        for id in txnQueue
          txn = txns[id]
          return if !txn || txn.timeout > now
          commit txn
        return

      fetchNewTxns = ->
        socket.emit 'txnsSince', memory.version + 1, model._startId, (err, newTxns, num) ->
          throw err if err

          # Apply any missed transactions first
          for txn in newTxns
            onTxn txn

          # Reset the number used to keep track of pending transactions
          txnApplier.clearPending()
          txnApplier.setIndex num + 1  if num?
          notReady = false

          # Resend all transactions in the queue
          for id in txnQueue
            commit txns[id]
          return

      txnApplier = new Serializer
        withEach: onTxn
        onTimeout: fetchNewTxns

      socket.on 'connect', ->
        fetchNewTxns()

        # Set an interval to check for transactions that have been in the queue
        # for too long and resend them
        resendInterval = setInterval resend, RESEND_INTERVAL unless resendInterval

      socket.on 'disconnect', ->
        notReady = true
        # Stop resending transactions while disconnected
        clearInterval resendInterval if resendInterval
        resendInterval = null

      model._addRemoteTxn = addRemoteTxn = (txn, num) ->
        if num?
          txnApplier.add txn, num
        else
          onTxn txn
      socket.on 'txn', addRemoteTxn

      # The model receives 'txnOk' from the server/store after the server/store
      # applies the transaction successfully
      socket.on 'txnOk', (txnId, ver, num) ->
        return unless txn = txns[txnId]
        transaction.setVer txn, ver
        addRemoteTxn txn, num

      socket.on 'txnErr', (err, txnId) ->
        txn = txns[txnId]
        if txn && (callback = txn.callback)
          if transaction.isCompound txn
            callbackArgs = transaction.ops txn
          else
            callbackArgs = transaction.getArgs(txn).slice 0
          callbackArgs.unshift err
          callback callbackArgs...
        removeTxn txnId

      model._commit = commit = (txn) ->
        return if txn.isPrivate || notReady
        txn.timeout = +new Date + SEND_TIMEOUT
        socket.emit 'txn', txn, model._startId

  server:
    _commit: (txn) ->
      return if txn.isPrivate
      @store._commit txn, (err, txn) =>
        return @_removeTxn transaction.getId txn  if err
        @_onTxn txn

  proto:
    # The value of @_force is checked in @_addOpAsTxn. It can be used to create a
    # transaction without conflict detection, such as model.force().set
    force: -> Object.create this, _force: value: true

    _commit: ->

    _asyncCommit: (txn, callback) ->
      return callback 'disconnected'  unless @connected
      txn.callback = callback
      id = transaction.getId txn
      @_txns[id] = txn
      @_commit txn

    _nextTxnId: -> @_clientId + '.' + @_count.txn++

    _queueTxn: (txn, callback) ->
      txn.callback = callback
      id = transaction.getId txn
      @_txns[id] = txn
      @_txnQueue.push id

    _getVersion: -> if @_force then null else @_memory.version

    _addOpAsTxn: (method, args, callback) ->
      # Refs may mutate the args in its 'beforeTxn' handler
      @emit 'beforeTxn', method, args

      return unless (path = args[0])?

      # Create a new transaction
      ver = @_getVersion()
      id = @_nextTxnId()
      txn = transaction.create {ver, id, method, args}
      txn.isPrivate = isPrivate path

      # Add remove index as txn metadata. Null if transaction does nothing
      if method is 'pop'
        txn.push (arr = @get(path) || null) && (arr.length - 1)
      else if method is 'unshift'
        txn.push (@get(path) || null) && 0

      # Queue and evaluate the transaction
      @_queueTxn txn, callback
      out = @_specModel().$out

      # Add insert index as txn metadata
      if method is 'push'
        txn.push out - args.length + 1

      # Clone the args, so that they can be modified before being emitted
      # without affecting the txn args
      args = args.slice()
      # Emit an event immediately on creation of the transaction, unless
      # already emitted. This may have happened for a private path that was
      # applied when evaluating the speculative model.
      unless txn.emitted
        @emit method, args, out, true, @_pass
        txn.emitted = true

      # Send it over Socket.IO or to the store on the server
      @_commit txn
      return out

    _applyTxn: (txn, isLocal) ->
      @_removeTxn txnId if txnId = transaction.getId txn
      data = @_memory._data
      doEmit = !txn.emitted
      ver = Math.floor transaction.getVer txn
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
          callback null, transaction.getArgs(txn)..., out
      return out

    _applyMutation: (extractor, txn, ver, data, doEmit, isLocal) ->
      method = extractor.getMethod txn
      return if method is 'get'
      args = extractor.getArgs txn
      out = @_memory[method] args..., ver, data
      if doEmit
        if patch = txn.patch
          for {method, args} in patch
            @emit method, args, null, isLocal, @_pass
        else
          @emit method, args, out, isLocal, @_pass
          txn.emitted = true
      return out

    _specModel: ->
      txns = @_txns
      txnQueue = @_txnQueue
      while (txn = txns[txnQueue[0]]) && txn.isPrivate
        out = @_applyTxn txn, true

      unless len = txnQueue.length
        data = @_memory._data
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
        data = cache.data = specCreate @_memory._data

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
      cache.lastTxnId = transaction.getId txn

      data.$out = out
      return data

    # TODO: Finish implementation of atomic transactions
    # atomic: (block, callback) ->
    #   model = new AtomicModel @_nextTxnId(), this
    #   @_atomicModels[model.getId] = model
    #   commit = (_callback) =>
    #     model._commit (err) =>
    #       delete @_atomicModels[model.getId] unless err
    #       _callback.apply null, arguments if _callback ||= callback
    #   abort = ->
    #   retry = ->

    #   if block.length == 1
    #     block model
    #     commit callback
    #   else if block.length == 2
    #     block model, commit
    #   else if block.length == 3
    #     block model, commit, abort
    #   else if block.length == 4
    #     block model, commit, abort, retry
