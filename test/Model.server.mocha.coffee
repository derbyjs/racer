should = require 'should'
Store = require '../src/Store'

run = (options) ->

  store = null
  beforeEach (done) ->
    store = new Store options
    store.flush done

  afterEach (done) ->
    store.flush ->
      store._redisClient.end()
      store._subClient.end()
      store._txnSubClient.end()
      done()

  it 'bundle should wait for the model transactions to be committed AND applied', (done) ->
      model = store.createModel()
      model.subscribe _preso: 'presos.racer', ->
        model.set 'presos.racer', { slides: [] }
        model.bundle (bundle) ->
          {data} = JSON.parse bundle
          # transactions committed
          model._txnQueue.should.be.empty
          # and applied
          data.presos.racer.should.eql { slides: [] }
          done()
   
    it 'bundle should not pass anything speculative to the data key when using 2 speculative sets  with a shared path (aka lazy speculative marking of an object that was the value of a set  should not modify the object itself)', (done) ->
      model = store.createModel()
      model.subscribe _preso: 'presos.racer', ->
        model.set 'presos.racer', { slides: [] }
        model.set 'presos.racer.role', 'presenter'
        model.bundle (bundle) ->
          obj = JSON.parse bundle
          should.equal undefined, obj.data.presos.racer._proto
          done()


describe 'Model.server', ->
  describe 'stm', -> run stm: true
  describe 'lww', -> run()
