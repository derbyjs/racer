Promise = require '../util/Promise'
transaction = require '../transaction'

module.exports =
  type: 'Store'

  events:
    init: (store) ->
      clientSockets = store._clientSockets
      localModels = store._localModels

      nextTxnNum = {}
      store._txnClock = txnClock =
        unregister: (clientId) ->
          delete nextTxnNum[clientId]

        register: (clientId) ->
          nextTxnNum[clientId] = 1

        nextTxnNum: (clientId) ->
          @register clientId unless clientId of nextTxnNum
          nextTxnNum[clientId]++

      # clientId -> {timeout, buffer}
      store._txnBuffers = {}

      store._pubSub.on 'txn', (clientId, txn) ->
        # Don't send transactions back to the model that created them.
        # On the server, the model directly handles the store._commit callback.
        # Over Socket.io, a 'txnOk' message is sent instead.
        return if clientId == transaction.getClientId txn
        # For models only present on the server, process the transaction
        # directly in the model
        return model._onTxn txn if model = localModels[clientId]

        # Otherwise, send the transaction over Socket.io
        if socket = clientSockets[clientId]
          # Prevent sending duplicate transactions by only sending new versions
          ver = transaction.getVer txn
          if ver > socket.__ver
            socket.__ver = ver
            num = txnClock.nextTxnNum clientId
            socket.emit 'txn', txn, num

        # However, the client may not be connected, which is true in the
        # following scenarios:
        #
        # 1. During initial Model#bundle and socket 'connection' event
        # 2. If a browser loses connection
        else if buffer = store._txnBuffer clientId
          buffer.push txn

    socket: (store, socket, clientId) ->
      txnClock = store._txnClock
      # This is used to prevent emitting duplicate transactions
      socket.__ver = 0

      socket.on 'txn', (txn, clientStartId) ->
        # TODO We can re-fashion this as middleware for socket.io
        ver = transaction.getVer txn
        store._checkVersion ver, clientStartId, (err) ->
          return socket.emit 'fatalErr', err if err
          store._commit txn, (err) ->
            txnId = transaction.getId txn
            ver = transaction.getVer txn
            # Return errors to client, with the exeption of duplicates, which
            # may need to be sent to the model again
            return socket.emit 'txnErr', err, txnId if err && err != 'duplicate'
            num = txnClock.nextTxnNum clientId
            socket.emit 'txnOk', txnId, ver, num

      socket.on 'disconnect', ->
        delete store._clientSockets[clientId]
        # Start buffering transactions on behalf of this disconnected client.
        # Buffering occurs for up to 3 seconds.
        store._startTxnBuffer clientId, 3000

      # Check to see if this socket connection is
      # 1. The first connection after the server ships the bundled model to the browser.
      # 2. A connection that occurs shortly after an aberrant disconnect
      if store._txnBuffer clientId
        # If so, the store has been buffering any transactions meant to be
        # received by the (disconnected) browser model because of model subscriptions.

        # So stop buffering the transactions
        store._cancelTxnBufferExpiry clientId
        # And send the buffered transactions to the browser
        store._flushTxnBuffer clientId, socket
      else
        # Otherwise, the server store has completely forgotten about this
        # client because it has been disconnected too long. In this case, the
        # store should
        # 1. Ask the browser model what it is subscribed to, so we can re-establish subscriptions
        # 2. Send the browser model enough data to bring it up to speed with
        #    the current data snapshot according to the server. When the store uses a journal, then it can send the browser a set of missing transactions. When the store does not use a journal, then it sends the browser a new snapshot of what the browser is interested in; the browser can then set itself to the new snapshot and diff it against its stale snapshot to reply the diff to the DOM, which reflects the stale state.
        socket.emit 'resyncWithStore', (subs, clientVer, clientStartId) ->
          store._onSnapshotRequest clientVer, clientStartId, clientId, socket, subs, 'shouldSubscribe'

  proto:

    _commit: (txn, callback) ->
      @_mode.commit txn, callback

    _startTxnBuffer: (clientId, timeoutAfter = 3000) ->
      txnBuffers = @_txnBuffers
      if clientId of txnBuffers
        console.warn "Already buffering transactions for client #{clientId}"
        console.trace()
        return
      txnBuffers[clientId] =
        buffer: buffer = []
        timeout: setTimeout =>
          @unsubscribe clientId
          @_txnClock.unregister clientId
          delete txnBuffers[clientId]
        , timeoutAfter

      return buffer

    _txnBuffer: (clientId) ->
      @_txnBuffers[clientId]?.buffer

    _cancelTxnBufferExpiry: (clientId) ->
      clearTimeout @_txnBuffers[clientId].timeout

    _flushTxnBuffer: (clientId, socket) ->
      txnBuffers = @_txnBuffers
      txns = txnBuffers[clientId].buffer
      socket.emit 'snapshotUpdate:newTxns', txns
      delete txnBuffers[clientId]
