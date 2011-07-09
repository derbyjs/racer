var Model, Store, fn, modelServer, name, store;
Model = require('./Model');
modelServer = require('./Model.server');
Store = require('./Store');
for (name in modelServer) {
  fn = modelServer[name];
  Model.prototype[name] = fn;
}
module.exports = {
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