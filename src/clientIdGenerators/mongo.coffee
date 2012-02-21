mongo = require 'mongodb'
NativeObjectId = mongo.BSONPure.ObjectID

module.exports = ->
  return (callback) ->
    try
      guid = (new NativeObjectId).toString()
      callback null, guid
    catch e
      callback e
