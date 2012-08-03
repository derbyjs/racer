Memory = require '../Memory'
Promise = require '../util/Promise'
Serializer = require '../Serializer'
transaction = require '../transaction'
{isPrivate} = require '../path'
{create: specCreate} = require '../util/speculative'
# AtomicModel = require './AtomicModel'
createMiddleware = require '../middleware'
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

      model._count = txn: 0

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
      model._onTxn = (txn) ->
        return unless txn?

        # Copy meta properties onto this transaction if it matches one in the queue
        if txnQ = txns[transaction.getId txn]
          txn.callback = txnQ.callback
          txn.emitted = txnQ.emitted

        isLocal = 'callback' of txn

        ver = transaction.getVer txn
        if ver > memory.version || ver == -1
          model._applyTxn txn, isLocal
        return

    middleware: (_model, middleware) ->
      middleware.txn = createMiddleware()

      # Normalize
      middleware.txn.add (req, res, next) ->
        txn = req.data
        method = transaction.getMethod txn
        args = transaction.getArgs txn
        # Refs may mutate the args in its 'beforeTxn' handler
        model = req.model
        model.emit 'beforeTxn', method, args
        return unless (path = args[0])?
        txn.isPrivate = isPrivate path

        args = transaction.getArgs txn
        txn.emitted = args.cancelEmit

        # Add remove index as txn metadata. Null if transaction does nothing
        if method is 'pop'
          txn.push (arr = model.get(path) || null) && (arr.length - 1)
        else if method is 'unshift'
          txn.push (model.get(path) || null) && 0
        return next()

      # TODO Typecast
      # middleware.txn.add typecast

      # TODO Validate
      # middleware.txn.add validate

      # Log the tranasaction
      middleware.txn.add (req, res, next) ->
        txn = req.data
        model = req.model
        id = transaction.getId txn
        model._txns[id] = txn
        model._txnQueue.push id
        return next()

      # Evaluate the transaction, which is now on the queue
      middleware.txn.add (req, res, next) ->
        model = req.model
        res.out = model._specModel().$out
        return next()

      # Send the transaction ...
      # - ... over Socket.IO if a browser Model
      # - ... to the store if a server Model
      #
      # Commit needs to happen before emit, since emissions might create
      # other transactions as a side effect
      middleware.txn.add (req, res, next) ->
        txn = req.data

        # Add insert index as txn metadata
        args = transaction.getArgs txn
        method = transaction.getMethod txn
        if method is 'push'
          out = res.out
          transaction.setMeta(out - args.length + 1)
          txn.push out - args.length + 1

        # Do the actual commit
        model = req.model
        model._commit txn
        return next()

      # Emit events
      middleware.txn.add (req, res, next) ->
        out = res.out
        txn = req.data

        # Emit an event immediately on creation of the transaction, unless
        # already emitted. This may have happened for a private path that was
        # applied when evaluating the speculative model.
        unless txn.emitted
          method = transaction.getMethod txn
          # Clone the args, so that they can be modified before being emitted
          # without affecting the txn args
          args = transaction.copyArgs txn
          model = req.model
          model.emit method, args, out, true, model._pass
          txn.emitted = true

        return out

    bundle: (model) ->
      model._txnsPromise.on (err) ->
        throw err if err
        clientId = model._clientId
        if store = model.store
          # In case we already unregistered local model
          # TODO Investigate why this is the case
          store._unregisterLocalModel clientId
        else
          console.warn "ALREADY UNREGISTERED SERVER MODEL"
          console.trace()
        # Start buffering subsequently received transactions. They will be
        # sent to the browser upon browser connection. This also occurs on 'disconnect'
        store._startTxnBuffer clientId
      # Get the speculative model, which will apply any pending private path
      # transactions that may get stuck in the first position of the queue
      model._specModel()
      # Wait for all pending transactions to complete before returning
      if model._txnQueue.length
        # TODO: This code is really confusing. Refactor
        model.__removeTxn__ ||= model._removeTxn
        model._removeTxn = (txnId) ->
          model.__removeTxn__ txnId
          len = model._txnQueue.length
          model._specModel()
          return if len

          process.nextTick ->
            model._txnsPromise.resolve()

        return
      model._txnsPromise.resolve()

    socket: (model, socket) ->
      {_memory: memory, _txns: txns, _txnQueue: txnQueue, _removeTxn: removeTxn, _onTxn: onTxn} = model

      # The startId is the ID of the last Journal restart. This is sent along with
      # each versioned message from the Model so that the Store can map the model's
      # version number to the version number of the Journal in case of a failure

      # These events are triggered by the 'resyncWithStore' event in the
      # reconnect mixin and the
      # txnApplier timeout below. A request is made to the server to fetch the
      # most recent snapshot, which is returned to the browser in one of many
      # forms on a channel prefixed with "snapshotUpdate:*"
      socket.on 'snapshotUpdate:replace', (data, num) ->
        # TODO Over-ride and replay diff as events?

        # Clear and remember any locally queued transactions. We recall the
        # remembered transactions later when we replay them on top of the
        # incoming snapshot.
        toReplay = (txns[txnId] for txnId in txnQueue)
        txnQueue.length = 0
        model._txns = txns = {}
        model._specCache.invalidate()

        # Reset the number used to keep track of pending transactions
        txnApplier.clearPending()
        txnApplier.setIndex num + 1 if num?

        memory.eraseNonPrivate()
        # TODO memory.flush?
        model._addData data

        model.emit 'reInit'

        for txn in toReplay
          # See mutators/mutators.Model
          model[transaction.getMethod txn] transaction.getArgs(txn)...

        return

      socket.on 'snapshotUpdate:newTxns', (newTxns, num) ->
        # Apply any missed transactions first
        onTxn txn for txn in newTxns

        # Reset the number used to keep track of pending transactions
        txnApplier.clearPending()
        txnApplier.setIndex num + 1  if num?

        # Resend all transactions in the queue
        for id in txnQueue
          # TODO In access control tests, same mutation sent twice as 2
          # different txns
          commit txns[id]
        return


      txnApplier = new Serializer
        withEach: onTxn

        # This timeout is for scenarios when a service that the server proxies to fails. This is for remote transactions.
        onTimeout: ->
          # TODO Make sure to set up the timeout again if we are disconnected
          return unless model.connected
          # TODO Don't do this if we are also responding to a resyncWithStore
          socket.emit 'fetch:snapshot', memory.version + 1, model._startId, model._subs()

      # Set an interval to check for transactions that have been in the queue
      # for too long and resend them
      resendInterval = null
      resend = ->
        now = +new Date
        # Evaluate to clear out private transactions at the beginning of the queue
        model._specModel()
        for id in txnQueue
          txn = txns[id]
          return if !txn || txn.timeout > now
          commit txn
        return
      setupResendInterval = ->
        resendInterval ||= setInterval resend, RESEND_INTERVAL
      teardownResendInterval = ->
        clearInterval resendInterval if resendInterval
        resendInterval = null
      if model.connected
        setupResendInterval()
      else
        model.once 'connect', ->
          setupResendInterval()

      socket.on 'disconnect', ->
        # Stop resending transactions until reconnect
        teardownResendInterval()

        # TODO Stop asking for missed remote transactions until reconnect

      model._addRemoteTxn = addRemoteTxn = (txn, num) ->
        if num?
          txnApplier.add txn, num
        else
          onTxn txn

      socket.on 'txn', addRemoteTxn

      # The model receives 'txnOk' from the server/store after the server/store
      # applies a transaction that originated from this model successfully
      socket.on 'txnOk', (rcvTxn, num) ->
        txnId = transaction.getId rcvTxn
        return unless txn = txns[txnId]
        ver = transaction.getVer rcvTxn
        transaction.setVer txn, ver
        addRemoteTxn txn, num

      # The model receives 'txnErr' from the server/store after the
      # server/store attempts to apply this transaction but fails
      socket.on 'txnErr', (err, txnId) ->
        txn = txns[txnId]
        if txn && (callback = txn.callback)
          if transaction.isCompound txn
            callbackArgs = transaction.ops txn
          else
            callbackArgs = transaction.copyArgs txn
          callbackArgs.unshift err
        removeTxn txnId
        if callback
          callback callbackArgs...

      model._commit = commit = (txn) ->
        return if txn.isPrivate
        txn.timeout = +new Date + SEND_TIMEOUT

        # Don't queue this up in socket.io's message buffer. Instead, we
        # explicitly send over any txns in the @_txnQueue during reconnect
        # synchronization.
        return unless model.connected

        socket.emit 'txn', txn, model._startId

  server:
    _commit: (txn) ->
      return if txn.isPrivate
      req =
        data: txn
        ignoreStartId: true
        clientId: @_clientId
        session: @session
      res =
        fail: (err, txn) =>
          @_removeTxn transaction.getId txn
          txn.callback err, txn
        send: (txn) => @_onTxn txn
      @store.middleware.txn req, res

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

    _opToTxn: (method, args, callback) ->
      ver = @_getVersion()
      id = @_nextTxnId()
      txn = transaction.create {ver, id, method, args}
      txn.callback = callback
      return txn

    _sendToMiddleware: (method, args, callback) ->
      txn = @_opToTxn method, args, callback
      req =
        data: txn
        # Pass in model, just in case scoped model where we need to access
        # model._pass
        model: @
      res =
        fail: (err) -> throw err
        send: -> console.log("TODO")
      return @middleware.txn req, res

    _applyTxn: (txn, isLocal) ->
      @_removeTxn txnId if txnId = transaction.getId txn
      data = @_memory._data
      doEmit = !txn.emitted
      # TODO Do we need Math.floor anymore?
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

    # `extractor` is either `transaction` or `transaction.op`
    _applyMutation: (extractor, txn, ver, data, doEmit, isLocal) ->
      out = extractor.applyTxn txn, data, @_memory, ver
      if doEmit
        if patch = txn.patch
          for {method, args} in patch
            @emit method, args, null, isLocal, @_pass
        else
          method = transaction.getMethod txn
          args = transaction.getArgs txn
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
