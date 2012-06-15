var Async = require('./Async')
  , mutatorModelMixin = require('./mutators.Model')
  , modelStatic = mutatorModelMixin.static
  , modelProto  = mutatorModelMixin.proto
  , proto = {
      get: {
        type: 'accessor'
      , fn: function (path, callback) {
          return this._sendToDb('get', [path || ''], callback);
        }
      }
    }
  , asyncProto = Async.prototype;

for (var name in asyncProto) {
  var fn = asyncProto[name]
    , obj;
  proto[name] = (obj = modelProto[name])
                // {type: type, fn: fn} is interpreted by mixin
              ? {type: obj.type, fn: fn}
              : fn;
}

module.exports = { type: 'Store', static: modelStatic, proto: proto};
