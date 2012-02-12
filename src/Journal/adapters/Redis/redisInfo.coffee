# TODO Remove this
setStarts = (client, startsLength, ver, callback) ->
  client.multi()
    .lpush('starts', "#{+new Date}.#{startsLength},#{ver}")
    .publish('$redisInfo', 'starts')
    .exec (err) ->
      throw err if err
      callback null if callback

module.exports =
  # This function should be called once when the Redis server restarts.
  # It is meant to be called by the process that starts the Redis server,
  # and it is not meant to be called by Store instances in production.
  # Store.flush also calls this function, for use in development or testing
  onStart: (client, callback) ->
    client.multi()
      .llen('starts')
      .get('ver')
      .exec (err, values) ->
        if err
          return callback err if callback
          throw err
        [startsLength, ver] = values
        setStarts client, startsLength, ver || 0, callback

  _getStarts: getStarts = (client, callback) ->
    client.lrange 'starts', 0, -1, (err, starts) ->
      throw err if err
      if starts.length is 0
        # If Redis has no record of being started by the Racer loader, assign
        # a start value with a version of 0. Note that multiple Store instances
        # may all try to do this at once, so this code uses a watch / multi
        # block to make sure only one client does this.
        return client.watch 'starts', (err) ->
          throw err if err
          client.llen 'starts', (err, value) ->
            throw err if err
            if value > 0
              # If another call to starts has already set the value between
              # the time that the first lrange command was sent and the watch
              # on starts was applied, return before doing anything
              return client.unwatch 'starts', ->
                getStarts client, callback

            console.error 'WARNING: Redis server does not have any record of ' +
              'being started by the Racer Redis loader.'

            # Initialize the value for starts if it is empty
            setStarts client, 0, 0, ->
              getStarts client, callback
      # Return a list in the format [[startId, ver], ...] in order of most
      # recent start to least recent start
      callback (start.split ',' for start in starts)

  # This function is intended to be called by the Store when it first connects
  # to the Redis server. It will call the callback with the value of starts
  # immediately and whenever the '$redisInfo', 'starts' event is published
  subscribeToStarts: (subClient, client, callback) ->
    unless subClient.__startsListener
      subClient.__startsListener = true
      subClient.on 'message', (channel, message) ->
        return unless channel is '$redisInfo' && message is 'starts'
        getStarts client, callback
    subClient.subscribe '$redisInfo'
    getStarts client, callback
