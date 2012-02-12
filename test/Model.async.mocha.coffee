should = require 'should'
Store = require '../src/Store'

describe 'Model.async', ->
  store = null

  beforeEach (done) ->
    store = new Store mode: 'stm'
    store.flush done

  afterEach (done) ->
    store.flush ->
      store.disconnect()
      done()

  it 'test model.async.retry', (done) ->
    model = store.createModel()
    incr = (path, callback) ->
      model.async.retry (atomic) ->
        atomic.get path, (count = 0) ->
          atomic.set path, ++count
      , callback
    i = 5
    cbCount = 5
    while i--
      incr 'count', ->
        unless --cbCount
          setTimeout ->
            model.async.get 'count', (err, value) ->
              value.should.eql 5
              done()
          , 50
