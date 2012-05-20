exports = module.exports = (racer) ->
  racer.registerAdapter 'clientId', 'Redis', ClientIdRedis

exports.useWith = server: true, browser: false

exports.decorate = 'racer'

ClientIdRedis = (@_options) ->
  return

ClientIdRedis::generateFn = ->
  {redisClient} = @_options
  return (callback) ->
    redisClient.incr 'clientClock', (err, val) ->
      return callback err if err
      clientId = val.toString(36)
      callback null, clientId
