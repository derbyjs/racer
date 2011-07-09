var Model, Store, fn, io, methods, modelServer, name, rally, store, _;
_ = require('./util');
Model = require('./Model');
modelServer = require('./Model.server');
Store = require('./Store');
io = require('socket.io');
for (name in modelServer) {
  fn = modelServer[name];
  Model.prototype[name] = fn;
}
if (_.onServer) {
  rally = function(req, res, next) {
    var oldProto;
    if (!req.session) {
      throw 'Missing session middleware';
    }
    oldProto = rally.__proto__;
    rally = function(req, res, next) {
      var reqRally, _base;
      reqRally = req.rally = Object.create(rally);
      reqRally.clientId = (_base = req.session).clientId || (_base.clientId = rally.nextClientId++);
      return next();
    };
    rally.__proto__ = oldProto;
    return rally(req, res, next);
  };
  rally.nextClientId = 1;
} else {
  rally = {};
}
module.exports = rally;
methods = {
  store: store = new Store,
  subscribe: function(path, callback) {
    var model;
    model = new Model;
    return store.get(path, function(err, value, ver) {
      if (err) {
        callback(err);
      }
      model._set(path, value);
      model._base = ver;
      return callback(null, model);
    });
  },
  unsubscribe: function() {
    throw "Unimplemented";
  },
  use: function() {
    throw "Unimplemented";
  }
};
for (name in methods) {
  fn = methods[name];
  rally[name] = fn;
}
io = io.listen(3001);
io.sockets.on('connection', function(socket) {
  return socket.on('txn', function(data) {
    return socket.emit('txn', data);
  });
});