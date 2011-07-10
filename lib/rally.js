var Model, Store, browserify, clientIdCount, fn, fs, io, ioUri, modelServer, name, nextClientId, rally, store, transaction;
Model = require('./Model');
modelServer = require('./Model.server');
Store = require('./Store');
transaction = require('./transaction');
io = require('socket.io');
browserify = require('browserify');
fs = require('fs');
for (name in modelServer) {
  fn = modelServer[name];
  Model.prototype[name] = fn;
}
clientIdCount = 1;
nextClientId = function() {
  return (clientIdCount++).toString(36);
};
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
    var clientId, session;
    if (!req.session) {
      throw 'Missing session middleware';
    }
    session = req.session;
    session.clientId = clientId = session.clientId || nextClientId();
    req.model = new Model(clientId, ioUri);
    return next();
  };
};
rally.store = store = new Store;
rally.subscribe = function(path, callback) {
  var model;
  model = new Model(nextClientId(), ioUri);
  return store.get(path, function(err, value, ver) {
    if (err) {
      callback(err);
    }
    model._set(path, value);
    model._base = ver;
    return callback(null, model);
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