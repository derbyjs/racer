should = require 'should'
Stm = require 'server/Stm'
stm = new Stm()
mockSocketModel = require('../util/model').mockSocketModel
luaLock = require('../util/Stm').luaLock(stm)
luaUnlock = require('../util/Stm').luaUnlock(stm)
luaCommit = require('../util/Stm').luaCommit(stm)

module.exports =
  setup: (done) ->
    stm._client.flushdb (err) ->
      throw err if err
      done()
  teardown: (done) ->
    stm._client.flushdb (err) ->
      throw err if err
      done()
  
  'Lua lock script should replaced timed out locks': (done) ->
    luaLock 'color', 0, (err, values) ->
      console.log 1
      should.equal null, err
      values[0].should.be.above 0
    luaLock 'color', 0, (err, values) ->
      console.log 2
      should.equal null, err
      values.should.equal 0
    timeoutFn = ->
      luaLock 'color', 0, (err, values) ->
        should.equal null, err
        values[0].should.be.above 0
        done()
    setTimeout timeoutFn, (Stm._LOCK_TIMEOUT + 1) * 1000

  finishAll: (done) ->
    stm._client.end()
    done()

  ## !!!! PLACE ALL TESTS BEFORE finishAll
