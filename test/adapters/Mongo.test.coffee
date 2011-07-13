should = require 'should'
Store = require 'Store'
MemoryAdapter = require 'adapters/Memory'
store = new Store(MongoAdapter)
store.connect()

module.exports =
  setup: (done) ->
    store.flush done

  teardown: (done) ->
    store.flush done

  'should be able to get a path that is set': (done) ->
    store.set 'path', 'val', ver=1, (err) ->
      should.equal null, err
      store.get 'path', (err, val, ver) ->
        should.equal null, err
        val.should.equal 'path'
        ver.should.equal 1
        done()
