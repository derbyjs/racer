should = require 'should'
Stm = require 'Stm'
redis = require 'redis'
client = redis.createClient()
stm = new Stm client
stmUtil = require('./util/Stm')(stm, client)
luaLock = stmUtil.luaLock

module.exports =
  setup: (done) ->
    client.flushdb (err) ->
      throw err if err
      done()
  teardown: (done) ->
    client.flushdb (err) ->
      throw err if err
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

  finishAll: (done) ->
    client.end()
    done()

  ## !!!! PLACE ALL TESTS BEFORE finishAll
