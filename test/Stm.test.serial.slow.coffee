should = require 'should'
Stm = require 'Stm'
redis = require 'redis'
client = redis.createClient()
stm = new Stm client
stmUtil = require('./util/Stm')(stm, client)
luaLock = stmUtil.luaLock

finishAll = false
module.exports =
  setup: (done) ->
    client.flushdb done
  teardown: (done) ->
    if finishAll
      client.end()
      return done()
    client.flushdb done
  
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

  finishAll: (done) -> finishAll = true; done()

  ## !! PLACE ALL TESTS BEFORE finishAll !! ##
