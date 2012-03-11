{expect} = require '../util'
{run} = require '../util/store'

run 'Model.bundle', (store) ->

  it 'should wait for the model transactions to be committed', (done) ->
    model = store().createModel()
    model.subscribe 'presos.racer', (err, presos) ->
      presos.set {slides: []}
      model.bundle (bundle) ->
        data = JSON.parse(bundle)[1].data
        # transactions committed
        expect(model._txnQueue).to.be.empty
        # and applied
        expect(data).to.eql {presos: {racer: {id: 'racer', slides: []}}}
        done()

  it 'a private path transaction should not get stuck in the queue', (done) ->
    model = store().createModel()
    model.subscribe 'presos.racer', (err, presos) ->
      presos.set {slides: []}
      model.set '_role', 'presenter'
      model.bundle (bundle) -> done()
