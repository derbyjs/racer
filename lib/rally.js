var Model, Store, browserify, fs, io, ioSockets, ioUri, modelJson, modelServer, nextClientId, rally, store, transaction;
Model = require('./Model');
modelServer = require('./Model.server');
Store = require('./Store');
transaction = require('./transaction');
io = require('socket.io');
browserify = require('browserify');
fs = require('fs');
ioUri = '';
ioSockets = null;
module.exports = rally = function(options) {
  var ioPort;
  ioPort = options.ioPort || 80;
  ioUri = options.ioUri || ':' + ioPort;
  ioSockets = options.ioSockets || io.listen(ioPort).sockets;
  ioSockets.on('connection', function(socket) {
    return socket.on('txn', function(txn) {
      return store._commit(txn, function(err, txn) {
        if (err) {
          return socket.emit('txnFail', transaction.id(txn));
        }
        return ioSockets.emit('txn', txn);
      });
    });
  });
  return function(req, res, next) {
    var clientId, finish;
    if (!req.session) {
      throw 'Missing session middleware';
    }
    finish = function(clientId) {
      req.model = new Model(clientId, ioUri);
      return next();
    };
    if (clientId = req.session.clientId) {
      return finish(clientId);
    } else {
      return nextClientId(function(clientId) {
        req.session.clientId = clientId;
        return finish(clientId);
      });
    }
  };
};
rally.store = store = new Store;
rally.subscribe = function(path, callback) {
  return nextClientId(function(clientId) {
    var model;
    model = new Model(clientId, ioUri);
    return store.get(path, function(err, value, ver) {
      if (err) {
        callback(err);
      }
      model._set(path, value);
      model._base = ver;
      return callback(null, model);
    });
  });
};
rally.unsubscribe = function() {
  throw "Unimplemented";
};
rally.use = function() {
  throw "Unimplemented";
};
rally.js = function() {
  return browserify.bundle({
    require: 'rally'
  }) + fs.readFileSync(__dirname + '/../node_modules/socket.io/node_modules/socket.io-client/dist/socket.io.js');
};
nextClientId = function(callback) {
  return store._stm._client.incr('clientIdCount', function(err, value) {
    if (err) {
      throw err;
    }
    return callback(value.toString(36));
  });
};
Model.prototype._send = function(txn) {
  var onTxn, removeTxn;
  onTxn = this._onTxn;
  removeTxn = this._removeTxn;
  store._commit(txn, function(err, txn) {
    if (err) {
      return removeTxn(transaction.id(txn));
    }
    onTxn(txn);
    return ioSockets.emit('txn', txn);
  });
  return true;
};
Model.prototype.json = modelJson = function(callback, self) {
  if (self == null) {
    self = this;
  }
  if (self._txnQueue.length) {
    setTimeout(modelJson, 10, callback, self);
  }
  return callback(JSON.stringify({
    data: self._data,
    base: self._base,
    clientId: self._clientId,
    txnCount: self._txnCount,
    ioUri: self._ioUri
  }));
};