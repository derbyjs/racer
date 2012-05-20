exports = module.exports = (racer) ->
  racer.registerAdapter 'clientId', 'Mongo', ClientIdMongo

exports.useWith = server: true, browser: false
exports.decorate = 'racer'

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
