module.exports = {
  type: 'Store'
, events: {
    init: onInit
  , socket: onSocket
  }
};

function TxnBufferMap() {}

function onInit(store) {
  store._txnBuffers = new TxnBuffers(store);
}

function onSocket(store, socket, clientId) {
  socket.on('disconnect', function () {
    delete store._clientSockets[clientId];
    // Start buffering transactions on behalf of this disconnected client.
    // Buffering occurs for up to 3 seconds.
    store._txnBuffers.add(clientId);
  });

  // Check to see if this socket connection is
  // 1. The first connection after the server ships the bundled model to the browser.
  // 2. A connection that occurs shortly after an aberrant disconnect
  if (store._txnBuffers.get(clientId)) {
    // If so, the store has been buffering any transactions meant to be
    // received by the (disconnected) browser model because of model subscriptions.

    // Send the buffered transactions to the browser
    store._txnBuffers.flush(clientId, socket);
    // And stop buffering the transactions
    store._txnBuffers.remove(clientId);

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


function TxnBufferMap() {}
function TxnBuffer() {
  this.buffer = [];
  this.timeout = null;
}

function TxnBuffers(store) {
  this.store = store;
  this.map = new TxnBufferMap;
}

TxnBuffers.prototype.get = function(clientId) {
  return this.map[clientId];
}

TxnBuffers.prototype.add = function(clientId) {
  if (clientId in this.map) {
    console.warn('Already buffering transactions for client ' + clientId);
    console.trace();
    return;
  }
  var txnBuffer = new TxnBuffer
    , self = this
  this.map[clientId] = txnBuffer;
  txnBuffer.timeout = setTimeout(function() {
    self.remove(clientId);
    self.store.unsubscribe(clientId);
    self.store._txnClock.unregister(clientId);
  }, 3000);
}

TxnBuffers.prototype.remove = function(clientId) {
  var txnBuffer = this.get(clientId);
  if (!txnBuffer) return;
  clearTimeout(txnBuffer.timeout);
  delete this.map[clientId];
}

TxnBuffers.prototype.flush = function(clientId, socket) {
  var txnBuffer = this.get(clientId);
  if (!txnBuffer) return;
  socket.emit('snapshotUpdate:newTxns', txnBuffer.buffer);
}

TxnBuffers.prototype.send = function(clientId, txn) {
  var txnBuffer = this.get(clientId);
  if (!txnBuffer) return;
  txnBuffer.buffer.push(txn);
}
