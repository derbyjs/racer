var Model, Store, browserify, clientJs, fn, modelServer, name, store;
Model = require('./Model');
modelServer = require('./Model.server');
Store = require('./Store');
browserify = require('browserify');
for (name in modelServer) {
  fn = modelServer[name];
  Model.prototype[name] = fn;
}
clientJs = browserify.bundle({
  require: __dirname + '/Model.js'
});
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
  js: function() {
    return clientJs;
  },
  unsubscribe: function() {
    throw "Unimplemented";
  },
  use: function() {
    throw "Unimplemented";
  }
};