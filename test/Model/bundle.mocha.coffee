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

  it 'bundle invocation before all txns have been applied should wait for all txns to be applied', (done) ->
    store = store()
    model = store.createModel()

    model.subscribe 'groups.racer', (err, group) ->
      group.set 'name', 'racer'

      # Simulate this latency scenario
      flush = ->
        fn() for fn in buffer
      commit = store._commit
      buffer = []
      store._commit = ->
        args = arguments
        buffer.push -> commit.apply(store, args)
      _bundle = model.bundle
      model.bundle = ->
        _bundle.apply model, arguments

      group.set 'age', 1
      model.bundle (bundle) ->
        {data} = JSON.parse(bundle)[1]
        expect(data.groups.racer).to.eql {id: 'racer', name: 'racer', age: 1}
        done()

      process.nextTick flush
