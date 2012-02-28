{expect} = require './util'
{run} = require './util/store'

run 'Model.async', {mode: 'stm'}, (store) ->

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
              expect(value).to.eql 5
              done()
          , 50
