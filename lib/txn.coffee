module.exports = class Txn
  constructor: (@clientId, @op, @skipClientVerIncr) ->
    if @clientId.constructor == Object
      throw new Error "You must have a clientId" unless Txn.prototype.clientId
      @skipClientVerIncr = op
      @op = @clientId
      @clientId = Txn.prototype.clientId # Assign from prototype
    protoVer = Txn.prototype.ver
    @ver = { client: protoVer.client, server: protoVer.server }
    protoVer.client++ unless skipClientVerIncr
    @id = "#{@clientId}.#{@ver.client}"
    @clock = [@id, @ver.server]
