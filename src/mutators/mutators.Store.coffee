Async = require './Async'
{static: modelStatic, proto: modelProto} = require './mutators.Model'

proto =
  get:
    type: 'accessor'
    fn: (path, callback) -> @_sendToDb 'get', [path || ''], callback

for name, fn of Async::
  proto[name] =
    if obj = modelProto[name]
      {type: obj.type, fn} # {type, fn} is interpreted by mixin
    else
      fn

module.exports = {type: 'Store', static: modelStatic, proto}
