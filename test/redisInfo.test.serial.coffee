redisInfo = require 'redisInfo'
redis = require 'redis'

checkFirstStart = (starts) ->
  starts.length.should.eql 1
  startId = starts[0][0]
  ver = starts[0][1]
  [startTime, startsLength] = startId.split '.'
  (new Date - startTime).should.be.within 0, 100
  startsLength.should.eql 0
  ver.should.eql 0

client = null
module.exports =
  setup: (done) ->
    client = redis.createClient()
    client.flushdb done
  teardown: (done) ->
    client.flushdb ->
      client.end()
      done()
  
  'starts should work with an uninitialized Redis instance': (done) ->
    redisInfo.starts client, (starts) ->
      checkFirstStart starts
      done()
  
  'starts should work after calling onStart': (done) ->
    redisInfo.onStart client, ->
      redisInfo.starts client, (starts) ->
        checkFirstStart starts
        done()