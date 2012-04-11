{expect} = require '../util'
racer = require '../../lib/racer'

describe 'Model.async', ->
  beforeEach (done) ->
    store = @store= racer.createStore
      mode:
        type: 'stm'
    store.flush done

  afterEach (done) ->
    @store.flush done

  it 'test model.async.retry', (done) ->
    model = @store.createModel()
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
              expect(value).to.eql 5
              done()
          , 50
