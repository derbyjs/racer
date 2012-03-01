Promise = require '../Promise'
transaction = require '../transaction'

module.exports =
  type: 'Store'

  events:
    socket: (store, socket) ->
      journal = store._journal
      pubSub = store._pubSub
      # This is used to prevent emitting duplicate transactions
      socket.__base = 0

      # This promise is fulfilled in the pubSub.Store mixin
      socket._clientIdPromise = clientIdPromise = new Promise

      socket.on 'txn', (txn, clientStartId) ->
        ver = transaction.base txn
        store._checkVersion socket, ver, clientStartId, (err) ->
          return if err
          store._commit txn, (err) ->
            txnId = transaction.id txn
            ver = transaction.base txn
            # Return errors to client, with the exeption of duplicates, which
            # may need to be sent to the model again
            return socket.emit 'txnErr', err, txnId if err && err != 'duplicate'
            clientIdPromise.on (clientId) ->
              journal.nextTxnNum clientId, (err, num) ->
                throw err if err
                socket.emit 'txnOk', txnId, ver, num

      socket.on 'txnsSince', (ver, clientStartId, callback) ->
        store._checkVersion socket, ver, clientStartId, (err) ->
          return if err
          clientIdPromise.on (clientId) ->
            journal.txnsSince ver, clientId, pubSub, (err, txns) ->
              return callback err if err
              journal.nextTxnNum clientId, (err, num) ->
                return callback err if err
                if len = txns.length
                  socket.__base = transaction.base txns[len - 1]
                callback null, txns, num

  proto:
    _onTxnMsg: (clientId, txn) ->
      # Don't send transactions back to the model that created them.
      # On the server, the model directly handles the store._commit callback.
      # Over Socket.io, a 'txnOk' message is sent below.
      return if clientId == transaction.clientId txn
      # For models only present on the server, process the transaction
      # directly in the model
      return model._onTxn txn if model = @_localModels[clientId]
      # Otherwise, send the transaction over Socket.io
      if socket = @_clientSockets[clientId]
        # Prevent sending duplicate transactions by only sending new versions
        base = transaction.base txn
        if base > socket.__base
          socket.__base = base
          @_journal.nextTxnNum clientId, (err, num) ->
            throw err if err
            socket.emit 'txn', txn, num
