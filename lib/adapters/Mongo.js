var MongoAdapter;
var __slice = Array.prototype.slice;
module.exports = MongoAdapter = function(config) {
  this.client = new Db(config.db, new Server(config.host, config.port, {}));
};
MongoAdapter.prototype = {
  flush: function(callback) {},
  set: function(path, val, ver, callback) {},
  get: function(path, callback) {},
  mget: function(paths, callback) {},
  extract: function(path) {
    var id, namespace, nestedPathParts, _ref;
    _ref = path.split('.'), namespace = _ref[0], id = _ref[1], nestedPathParts = 3 <= _ref.length ? __slice.call(_ref, 2) : [];
    return ["" + namespace + "." + id, nestedPathParts.join('.')];
  }
};