Txn = module.exports = (clientId, op, skipClientVerIncr) ->
  if clientId.constructor == Object
    @clientId = @clientId # Assign from prototype
    op = clientId
    skipClientVerIncr = op
  else
    @clientId = clientId
  @ver = { client: @ver.client, server: @ver.server }
  Txn.prototype.ver.client++ unless skipClientVerIncr
