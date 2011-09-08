should = require 'should'
Store = require 'Store'

store = null

module.exports =
  setup: (done) ->
    store = new Store
    store.flush done
  teardown: (done) ->
    store.flush ->
      store._redisClient.end()
      store._subClient.end()
      store._txnSubClient.end()
      done()

  'bundle should wait for the model transactions to be committed AND applied': (done) ->
    store.subscribe _preso: 'presos.racer.**', (err, model) ->
      model.set 'presos.racer', { slides: [] }
      model.bundle (bundle) ->
        obj = JSON.parse bundle
        # transactions committed
        model._txnQueue.should.be.empty

        # and applied
        model.get('presos.racer').should.not.equal undefined
        done()

  'bundle should not pass anything speculative to the data key when using 2 speculative sets with a shared path (aka lazy speculative marking of an object that was the value of a set should not modify the object itself)': (done) ->
    store.subscribe _preso: 'presos.racer.**', (err, model) ->
      model.set 'presos.racer', { slides: [] }
      model.set 'presos.racer.role', 'presenter'
      model.bundle (bundle) ->
        obj = JSON.parse bundle
        should.equal undefined, obj.data.presos.racer._proto
        done()
