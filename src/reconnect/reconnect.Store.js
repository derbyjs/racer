// TODO Incomplete
module.exports = {
  type: 'Store'
, events: {
    init: function (store) {
      // clientId -> {timeout, buffer}
      store._txnBuffers = {};
    }
  , socket: function (store, socket, clientId) {
      socket.on('disconnect', function () {
        delete store._clientSockets[clientId];
        // Start buffering transactions on behalf of this disconnected client.
        // Buffering occurs for up to 3 seconds.
        store._startTxnBuffer(clientId, 3000);
      });

      // Check to see if this socket connection is
      // 1. The first connection after the server ships the bundled model to the browser.
      // 2. A connection that occurs shortly after an aberrant disconnect
      if (store._txnBuffer(clientId)) {
        // If so, the store has been buffering any transactions meant to be
        // received by the (disconnected) browser model because of model subscriptions.

        // So stop buffering the transactions
        store._cancelTxnBufferExpiry(clientId);
        // And send the buffered transactions to the browser
        store._flushTxnBuffer(clientId, socket);
      } else {
        // Otherwise, the server store has completely forgotten about this
        // client because it has been disconnected too long. In this case, the
        // store should
        // 1. Ask the browser model what it is subscribed to, so we can re-establish subscriptions
        // 2. Send the browser model enough data to bring it up to speed with
        //    the current data snapshot according to the server. When the store uses a journal, then it can send the browser a set of missing transactions. When the store does not use a journal, then it sends the browser a new snapshot of what the browser is interested in; the browser can then set itself to the new snapshot and diff it against its stale snapshot to reply the diff to the DOM, which reflects the stale state.
        socket.emit('resyncWithStore', function (subs, clientVer, clientStartId) {
          store._onSnapshotRequest(clientVer, clientStartId, clientId, socket, subs, 'shouldSubscribe');
        });
      }
    }
  }

, proto: {
    _startTxnBuffer: function (clientId, timeoutAfter) {
      var txnBuffers = this._txnBuffers;
      if (clientId in txnBuffers) {
        console.warn('Already buffering transactions for client ' + clientId);
        console.trace();
        return;
      }
      var buffer = []
        , self = this;
      txnBuffers[clientId] = {
        buffer: buffer
      , timeout: setTimeout(function () {
          self.unsubscribe(clientId);
          self._txnClock.unregister(clientId);
          delete txnBuffers[clientId];
        }, timeoutAfter || 3000)
      };
      return buffer;
    }
  , _txnBuffer: function (clientId) {
      var txnBuffers = this._txnBuffers
        , meta = txnBuffers[clientId];
      return meta && meta.buffer;
    }

  , _cancelTxnBufferExpiry: function (clientId) {
      clearTimeout(this._txnBuffers[clientId].timeout);
    }

  , _flushTxnBuffer: function (clientId, socket) {
      var txnBuffers = this._txnBuffers
        , txns = txnBuffers[clientId].buffer;
      socket.emit('snapshotUpdate:newTxns', txns);
      delete txnBuffers[clientId];
    }
  }
};
