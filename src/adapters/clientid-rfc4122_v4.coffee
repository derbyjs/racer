uuid = require 'node-uuid'

module.exports = (racer) ->
  racer.adapters.clientId.Rfc4122_v4 = ClientIdRfc4122_v4

ClientIdRfc4122_v4 = (@_options) ->
  return

ClientIdRfc4122_v4::generateFn = ->
  {options, buffer, offset} = @_options
  return (callback) ->
    clientId = uuid.v4 options, buffer, offset
    callback null, clientId
