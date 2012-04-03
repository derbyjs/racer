Promise = require '../Promise'
transaction = require '../transaction'

module.exports =
  type: 'Store'

  events:
    init: (store) ->
      clientSockets = store._clientSockets
      localModels = store._localModels
      journal = store._journal

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
            journal.nextTxnNum clientId, (err, num) ->
              throw err if err
              socket.emit 'txn', txn, num

    socket: (store, socket, clientId) ->
      journal = store._journal
      # This is used to prevent emitting duplicate transactions
      socket.__ver = 0

      socket.on 'txn', (txn, clientStartId) ->
        ver = transaction.getVer txn
        store._checkVersion socket, ver, clientStartId, (err) ->
          return socket.emit 'fatalErr', err if err
          store._commit txn, (err) ->
            txnId = transaction.getId txn
            ver = transaction.getVer txn
            # Return errors to client, with the exeption of duplicates, which
            # may need to be sent to the model again
            return socket.emit 'txnErr', err, txnId if err && err != 'duplicate'
            journal.nextTxnNum clientId, (err, num) ->
              throw err if err
              socket.emit 'txnOk', txnId, ver, num

      socket.on 'txnsSince', (ver, clientStartId, callback) ->
        store._checkVersion socket, ver, clientStartId, (err) ->
          return socket.emit 'fatalErr', err if err
          journal.txnsSince ver, clientId, store._pubSub, (err, txns) ->
            return callback err if err
            journal.nextTxnNum clientId, (err, num) ->
              return callback err if err
              if len = txns.length
                socket.__ver = transaction.getVer txns[len - 1]
              callback null, txns, num
