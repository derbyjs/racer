var Model, Store, clientIdCount, fn, io, modelServer, name, nextClientId, rally, store;
Model = require('./Model');
modelServer = require('./Model.server');
Store = require('./Store');
io = require('socket.io');
for (name in modelServer) {
  fn = modelServer[name];
  Model.prototype[name] = fn;
}
clientIdCount = 1;
nextClientId = function() {
  return (clientIdCount++).toString(36);
};
module.exports = rally = function(req, res, next) {
  var oldProto;
  if (!req.session) {
    throw 'Missing session middleware';
  }
  oldProto = rally.__proto__;
  rally = function(req, res, next) {
    var clientId;
    clientId = req.session.clientId || nextClientId();
    req.model = new Model(clientId);
    return next();
  };
  rally.__proto__ = oldProto;
  return rally(req, res, next);
};
rally.store = store = new Store;
rally.subscribe = function(path, callback) {
  var model;
  model = new Model(nextClientId());
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
io = io.listen(3001);
io.sockets.on('connection', function(socket) {
  return socket.on('txn', function(data) {
    socket.broadcast.emit('txn', data);
    return socket.emit('txn', data);
  });
});