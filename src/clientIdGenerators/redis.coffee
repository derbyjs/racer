module.exports = ({redisClient}) ->
  return (callback) ->
    redisClient.incr 'clientClock', (err, val) ->
      return callback err if err
      clientId = val.toString(36)
      callback null, clientId
