module.exports = (racer) ->
  racer.adapters.clientId.Mongo = ClientIdMongo

ClientIdMongo = (@_options) ->
  return

ClientIdMongo::generateFn = ->
  ObjectID = @_options.mongo.BSONPure.ObjectID
  return (callback) ->
    try
      guid = (new ObjectId).toString()
      callback null, guid
    catch e
      callback e
    return
