Promise = require '../Promise'
transaction = require '../transaction'

module.exports =
  type: 'Store'

  events:
    init: (store) ->
      clientSockets = store._clientSockets
      localModels = store._localModels
      txnClock = store._txnClock

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
        else
          if buffer = store._txnBuffer clientId
            buffer.push txn

    socket: (store, socket, clientId) ->
      txnClock = store._txnClock
      # This is used to prevent emitting duplicate transactions
      socket.__ver = 0

      socket.on 'txn', (txn, clientStartId) ->
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

      socket.on 'fetchCurrSnapshot', (ver, clientStartId, callback) ->
        if store._journal
          store._checkVersion ver, clientStartId, (err) ->
            return socket.emit 'fatalErr', err if err
            store._journal.txnsSince ver, clientId, store._pubSub, (err, txns) ->
              return callback err if err
              num = txnClock.nextTxnNum clientId
              if len = txns.length
                socket.__ver = transaction.getVer txns[len - 1]
              socket.emit 'snapshotUpdate', 'newTxns', null, txns, num
              callback null, txns, num
        else
          store.fetch clientId, subs, (err, data) ->
            socket.emit 'snapshotUpdate', data

  proto:
    _startTxnBuffer: (clientId, timeoutAfter = 3000) ->
      txnBuffers = @_txnBuffers
      if clientId of txnBuffers
        throw new Error "Already buffering transactions for client #{clientId}"
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
      for txn in txnBuffers[clientId].buffer
        socket.emit 'txn', txn
      delete txnBuffers[clientId]
