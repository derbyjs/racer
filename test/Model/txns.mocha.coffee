{expect, calls} = require '../util'
transaction = require '../../lib/transaction'
{mockFullSetup, mockSocketModel, mockSocketEcho, BrowserModel: Model} = require '../util/model'
{BrowserSocketMock} = require '../util/sockets'
racer = require '../../lib/racer'

describe 'Model transaction handling', ->

  it 'internal creation of client transactions on set', ->
    model = new Model
    model._clientId = '0'

    model.set 'color', 'green'
    expect(model._txnQueue).to.eql ['0.0']
    expect(model._txns['0.0'].slice()).to.eql transaction.create ver: 0, id: '0.0', method: 'set', args: ['color', 'green']

    model.set 'count', 0
    expect(model._txnQueue).to.eql ['0.0', '0.1']
    expect(model._txns['0.0'].slice()).to.eql transaction.create ver: 0, id: '0.0', method: 'set', args: ['color', 'green']
    expect(model._txns['0.1'].slice()).to.eql transaction.create ver: 0, id: '0.1', method: 'set', args: ['count', 0]

  it 'client performs set on receipt of message', ->
    [model, sockets] = mockSocketModel()
    sockets.emit 'txn', transaction.create(ver: 1, id: 'server0.0', method: 'set', args: ['color', 'green']), 1
    expect(model.get 'color').to.eql 'green'
    expect(model._memory.version).to.eql 1
    sockets._disconnect()

  it 'client set roundtrip with server echoing transaction', (done) ->
    [model, sockets] = mockSocketEcho '0'
    model.socket.on 'txnOk', (txn) ->
      txnId = transaction.getId txn
      expect(txnId).to.equal '0.0'
      expect(model.get 'color').to.eql 'green'
      expect(model._txnQueue).to.eql []
      expect(model._txns).to.eql {}
      sockets._disconnect()
      done()

    model.set 'color', 'green'
    expect(model._txnQueue).to.eql ['0.0']

  it 'client del roundtrip with server echoing transaction', (done) ->
    [model, sockets] = mockSocketEcho '0'
    model.socket.on 'txnOk', (txn) ->
      txnId = transaction.getId txn
      expect(txnId).to.equal '0.0'
      expect(model.get()).to.eql {}
      expect(model._txnQueue).to.eql []
      expect(model._txns).to.eql {}
      sockets._disconnect()
      done()

    model._memory._data = world: {color: 'green'}
    model.del 'color'
    expect(model._txnQueue).to.eql ['0.0']

  it 'client push roundtrip with server echoing transaction', (done) ->    
    [model, sockets] = mockSocketEcho '0'
    model.socket.on 'txnOk', (txn) ->
      txnId = transaction.getId txn
      expect(txnId).to.equal '0.0'
      expect(model.get 'colors').to.specEql ['red']
      expect(model._txnQueue).to.eql []
      expect(model._txns).to.eql {}
      sockets._disconnect()
      done()

    model.push 'colors', 'red'
    expect(model._txnQueue).to.eql ['0.0']

  it 'setting on a private path should only be applied locally', calls 0, (done) ->
    [model, sockets] = mockSocketModel '0', 'txn', done
    model.set '_color', 'green'
    expect(model.get '_color').to.eql 'green'
    expect(model._txnQueue).to.eql []
    sockets._disconnect()

  it 'transactions should be removed after failure', (done) ->
    [model, sockets] = mockSocketModel '0', 'txn', (txn) ->
      sockets.emit 'txnErr', 'conflict', '0.0'
      expect(model._txnQueue).to.eql []
      expect(model._txns).to.eql {}
      sockets._disconnect()
      done()

    model.set 'color', 'green'
    expect(model._txnQueue).to.eql ['0.0']

  it 'transactions received out of order should be applied in order', ->
    [model, sockets] = mockSocketModel()
    sockets.emit 'txn', transaction.create(ver: 1, id: '_.0', method: 'set', args: ['color', 'green']), 1
    expect(model.get 'color').to.eql 'green'

    sockets.emit 'txn', transaction.create(ver: 3, id: '_.0', method: 'set', args: ['color', 'red']), 3
    expect(model.get 'color').to.eql 'green'

    sockets.emit 'txn', transaction.create(ver: 2, id: '_.0', method: 'set', args: ['number', 7]), 2
    expect(model.get 'color').to.eql 'red'
    expect(model.get 'number').to.eql 7
    sockets._disconnect()

  it 'duplicate transaction versions should not be applied', ->
    [model, sockets] = mockSocketModel()
    sockets.emit 'txn', transaction.create(ver: 1, id: '_.0', method: 'push', args: ['colors', 'green']), 1
    sockets.emit 'txn', transaction.create(ver: 1, id: '_.0', method: 'push', args: ['colors', 'green']), 2
    expect(model.get 'colors').to.specEql ['green']
    sockets._disconnect()

  it 'transactions should be requested if it has not received its next expected txn in a while @slow', (done) ->
    # Txn serializer timeout is 1 second
    @timeout 2000
    store = racer.createStore()
    mockFullSetup store, done, [], (modelA, modelB, done) ->
      serverSocketA = modelA.socket._serverSocket # ServerSocketMock

      __emit__ = serverSocketA.emit
      serverSocketA.emit = (name, args...) ->
        # Don't send the 2nd txn, so we trigger txn serializer to time out
        return if name == 'txn' && transaction.getVer(args[0]) == 2
        # Send all other pub sub messages
        __emit__.call @, name, args...

      serverSocketA.listeners('fetch:snapshot').unshift ->
        expect(modelA.get '_test.color').to.eql 'red'
        modelA.on 'reInit', ->
          expect(modelA.get '_test.color').to.eql 'yellow'
          done()

      modelB.set '_test.color', 'red'
      modelB.set '_test.color', 'orange'
      modelB.set '_test.color', 'yellow'

  it 'transactions should not be requested if pending less than timeout', calls 0, (done) ->
    [model, sockets] = mockSocketModel '0', 'fetchCurrSnapshot', (ver) ->
      done()
    sockets.emit 'txn', transaction.create(ver: 1, id: '1.1', method: 'set', args: ['color', 'green']), 1
    sockets.emit 'txn', transaction.create(ver: 3, id: '1.3', method: 'set', args: ['color', 'green']), 3
    sockets.emit 'txn', transaction.create(ver: 2, id: '1.2', method: 'set', args: ['color', 'green']), 2
    setTimeout sockets._disconnect, 50

  it 'forcing a model method should create a transaction with a null version', ->
    model = new Model
    model._clientId = '0'
    model.set 'color', 'green'
    model.force().set 'color', 'red'
    model.force().del 'color'
    expect(model._txns['0.0'].slice()).to.eql transaction.create ver: 0, id: '0.0', method: 'set', args: ['color', 'green']
    expect(model._txns['0.1'].slice()).to.eql transaction.create ver: null, id: '0.1', method: 'set', args: ['color', 'red']
    expect(model._txns['0.2'].slice()).to.eql transaction.create ver: null, id: '0.2', method: 'del', args: ['color']

  it 'a forced model mutation should not result in an adapter ver of null or undefined', ->
    model = new Model
    model.set 'color', 'green'
    model.force().set 'color', 'red'
    expect(model._memory.version).to.not.be.null
    expect(model._memory.version).to.not.be.undefined

  it 'model mutator methods should callback on completion', calls 2, (done) ->
    ver = 0
    [model, sockets] = mockSocketModel '0', 'txn', (txn) ->
      transaction.setVer txn, ++ver
      sockets.emit 'txn', txn
      sockets._disconnect()
    model.set 'color', 'green', (err, path, value) ->
      expect(err).to.be.null()
      expect(path).to.equal 'color'
      expect(value).to.equal 'green'
      done()
    model.del 'color', (err, path) ->
      expect(err).to.be.null()
      expect(path).to.equal 'color'
      done()

  it 'model mutator methods should callback with error on confict', calls 2, (done) ->
    ver = 0
    [model, sockets] = mockSocketModel '0', 'txn', (txn) ->
      sockets.emit 'txnErr', 'conflict', transaction.getId txn
      sockets._disconnect()
    model.set 'color', 'green', (err, path, value) ->
      expect(err).to.equal 'conflict'
      expect(path).to.equal 'color'
      expect(value).to.equal 'green'
      done()
    model.del 'color', (err, path) ->
      expect(err).to.equal 'conflict'
      expect(path).to.equal 'color'
      done()
