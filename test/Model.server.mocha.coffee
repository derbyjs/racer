expect = require 'expect.js'
Store = require '../src/Store'

run = (options) ->

  store = null
  beforeEach (done) ->
    store = new Store options
    store.flush done

  afterEach (done) ->
    store.flush ->
      store.disconnect()
      done()

  it 'bundle should wait for the model transactions to be committed AND applied', (done) ->
    model = store.createModel()
    model.subscribe 'presos.racer', (presos) ->
      presos.set { slides: [] }
      model.bundle (bundle) ->
        {data} = JSON.parse bundle
        # transactions committed
        expect(model._txnQueue).to.be.empty
        # and applied
        expect(data.presos.racer).to.eql { slides: [] }
        done()

  it 'bundle should not pass anything speculative to the data key when using 2 speculative sets  with a shared path (aka lazy speculative marking of an object that was the value of a set  should not modify the object itself)', (done) ->
    model = store.createModel()
    model.subscribe 'presos.racer', (presos) ->
      presos.set { slides: [] }
      presos.set 'role', 'presenter'
      model.bundle (bundle) ->
        obj = JSON.parse bundle
        expect(obj.data.presos.racer._proto).to.equal undefined
        done()


describe 'Model.server', ->
  describe 'stm', -> run mode: 'stm'
  describe 'lww', -> run mode: 'lww'
