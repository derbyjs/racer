uuid = require 'node-uuid'

module.exports = (opts = {}) ->
  return (callback) ->
    {options, buffer, offset} = opts
    clientId = uuid.v4 options, buffer, offset
    callback null, clientId
