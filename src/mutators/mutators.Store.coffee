Async = require './Async'
{static, proto: modelProto} = require './mutators.Model'

proto =
  get:
    type: 'accessor'
    fn: (path, callback) -> @_sendToDb 'get', [path || ''], callback

for name, fn of Async::
  proto[name] =
    if obj = modelProto[name] then {type: obj.type, fn} else fn

module.exports = {type: 'Store', static, proto}
