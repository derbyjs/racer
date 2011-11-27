should = require 'should'
Stm = require '../src/Stm'
redis = require 'redis'
client = null
stm = null
stmUtil = null
luaLock = null

module.exports =
  setup: (done) ->
    client = redis.createClient()
    stm = new Stm client
    stmUtil = require('./util/Stm')(stm, client)
    luaLock = stmUtil.luaLock
    client.flushdb (err) ->
      throw err if err
      done()
  teardown: (done) ->
    client.flushdb (err) ->
      throw err if err
      client.quit()
      done()
  
  'Lua lock script should replaced timed out locks': (done) ->
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      values[0].should.be.above 0
    luaLock 'color', 0, (err, values) ->
      should.equal null, err
      values.should.equal 0
    timeoutFn = ->
      luaLock 'color', 0, (err, values) ->
        should.equal null, err
        values[0].should.be.above 0
        done()
    setTimeout timeoutFn, (Stm._LOCK_TIMEOUT + 1) * 1000
