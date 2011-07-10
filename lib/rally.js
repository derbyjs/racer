var Model, Store, browserify, fn, fs, io, ioUri, modelServer, name, nextClientId, rally, stm, store, transaction;
Model = require('./Model');
modelServer = require('./Model.server');
Store = require('./Store');
transaction = require('./transaction');
io = require('socket.io');
browserify = require('browserify');
fs = require('fs');
ioUri = '';
module.exports = rally = function(options) {
  var ioPort, ioSockets;
  ioPort = options.ioPort || 80;
  ioUri = options.ioUri || ':' + ioPort;
  ioSockets = options.ioSockets || io.listen(ioPort).sockets;
  ioSockets.on('connection', function(socket) {
    return socket.on('txn', function(txn) {
      return store._commit(txn, function(err, txn) {
        if (err) {
          return socket.emit('txnFail', transaction.id(txn));
        }
        socket.broadcast.emit('txn', txn);
        return socket.emit('txn', txn);
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
for (name in modelServer) {
  fn = modelServer[name];
  Model.prototype[name] = fn;
}
stm = store._stm;
nextClientId = function(callback) {
  return stm._client.incr('clientIdCount', function(err, value) {
    if (err) {
      throw err;
    }
    return callback(value.toString(36));
  });
};