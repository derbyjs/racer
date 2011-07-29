startValue = (startsLength, ver) -> "#{+new Date}.#{startsLength},#{ver}"

redisInfo = module.exports =

  # This function should be called once when the Redis server restarts.
  # It is meant to be called by the process that starts the Redis server, and
  # is not meant to be called by Store instances connecting to Redis
  onStart: (client, callback) ->
    client.multi()
      .llen('starts')
      .get('ver')
      .exec (err, values) ->
        throw err if err
        startsLength = values[0]
        ver = values[1] || 0
        client.lpush 'starts', startValue(startsLength, ver), (err) ->
          throw err if err
          callback()
  
  # This function is intended to be called by the Store every time it connects
  # to the Redis server.
  starts: getStarts = (client, callback) ->
    client.lrange 'starts', 0, -1, (err, starts) ->
      throw err if err
      if starts.length is 0
        console.warn 'WARNING: Redis server does not have any record of ' +
          'being started by the Rally Redis loader. This should not occur in ' +
          'production, and may be the result of a flush of the database.'
        # If Redis has no record of being started by the Rally loader, assign
        # a start value with a version of 0. Note that multiple Store instances
        # may all try to do this at once, so this code uses a watch / multi
        # block to make sure only one client does this.
        return client.watch 'starts', (err) ->
          throw err if err
          client.llen 'starts', (err, value) ->
            throw err if err
            if value > 0
              return client.unwatch 'starts', ->
                getStarts client, callback
            client.multi()
              .lpush('starts', startValue(0, 0))
              .exec (err) ->
                throw err if err
                getStarts client, callback
      # Return a list in the format [[startId, ver], ...] in order of most
      # recent start to least recent start
      callback (start.split ',' for start in starts)
