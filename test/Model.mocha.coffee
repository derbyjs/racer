transaction = require '../src/transaction'
Model = require '../src/Model'
expect = require 'expect.js'
{calls} = require './util'
{mockSocketModel, mockSocketEcho} = require './util/model'

describe 'Model', ->

  it 'get should return the adapter data when there are no pending transactions', ->
    model = new Model
    model._adapter._data = world: {a: 1}
    expect(model.get()).to.eql {a: 1}
  
  it 'test internal creation of client transactions on set', ->
    model = new Model '0'
    
    model.set 'color', 'green'
    expect(model._txnQueue).to.eql ['0.0']
    expect(model._txns['0.0'].slice()).to.eql transaction.create base: 0, id: '0.0', method: 'set', args: ['color', 'green']
    
    model.set 'count', 0
    expect(model._txnQueue).to.eql ['0.0', '0.1']
    expect(model._txns['0.0'].slice()).to.eql transaction.create base: 0, id: '0.0', method: 'set', args: ['color', 'green']
    expect(model._txns['0.1'].slice()).to.eql transaction.create base: 0, id: '0.1', method: 'set', args: ['count', 0]

  it 'test client performs set on receipt of message', ->
    [model, sockets] = mockSocketModel()
    sockets.emit 'txn', transaction.create(base: 1, id: 'server0.0', method: 'set', args: ['color', 'green']), 1
    expect(model.get 'color').to.eql 'green'
    expect(model._adapter.version).to.eql 1
    sockets._disconnect()

  it 'test client set roundtrip with server echoing transaction', (done) ->
    [model, sockets] = mockSocketEcho '0'
    model.socket.on 'txnOk', (txnId) ->
      expect(txnId).to.equal '0.0'
      expect(model.get 'color').to.eql 'green'
      expect(model._txnQueue).to.eql []
      expect(model._txns).to.eql {}
      sockets._disconnect()
      done()
    
    model.set 'color', 'green'
    expect(model._txnQueue).to.eql ['0.0']

  it 'test client del roundtrip with server echoing transaction', (done) ->
    [model, sockets] = mockSocketEcho '0'
    model.socket.on 'txnOk', (txnId) ->
      expect(txnId).to.equal '0.0'
      expect(model.get()).to.eql {}
      expect(model._txnQueue).to.eql []
      expect(model._txns).to.eql {}
      sockets._disconnect()
      done()

    model._adapter._data = world: {color: 'green'}
    model.del 'color'
    expect(model._txnQueue).to.eql ['0.0']

  it 'test client push roundtrip with server echoing transaction', (done) ->    
    [model, sockets] = mockSocketEcho '0'
    model.socket.on 'txnOk', (txnId) ->
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
    sockets.emit 'txn', transaction.create(base: 1, id: '_.0', method: 'set', args: ['color', 'green']), 1
    expect(model.get 'color').to.eql 'green'
    
    sockets.emit 'txn', transaction.create(base: 3, id: '_.0', method: 'set', args: ['color', 'red']), 3
    expect(model.get 'color').to.eql 'green'
    
    sockets.emit 'txn', transaction.create(base: 2, id: '_.0', method: 'set', args: ['number', 7]), 2
    expect(model.get 'color').to.eql 'red'
    expect(model.get 'number').to.eql 7
    sockets._disconnect()
  
  it 'duplicate transaction versions should not be applied', ->
    [model, sockets] = mockSocketModel()
    sockets.emit 'txn', transaction.create(base: 1, id: '_.0', method: 'push', args: ['colors', 'green']), 1
    sockets.emit 'txn', transaction.create(base: 1, id: '_.0', method: 'push', args: ['colors', 'green']), 2
    expect(model.get 'colors').to.specEql ['green']
    sockets._disconnect()
  
  it 'transactions should be requested if pending longer than timeout @slow', (done) ->
    @timeout 2000
    ignoreFirst = true
    [model, sockets] = mockSocketModel '0', 'txnsSince', (ver) ->
      # A txnsSince request is sent immediately upon connecting,
      # so the first one should be ignored
      return ignoreFirst = false  if ignoreFirst
      expect(ver).to.eql 3
      sockets._disconnect()
      done()
    sockets.emit 'txn', transaction.create(base: 1, id: '1.1', method: 'set', args: ['color', 'green']), 1
    sockets.emit 'txn', transaction.create(base: 2, id: '1.2', method: 'set', args: ['color', 'green']), 2
    sockets.emit 'txn', transaction.create(base: 4, id: '1.4', method: 'set', args: ['color', 'green']), 4
    sockets.emit 'txn', transaction.create(base: 5, id: '1.5', method: 'set', args: ['color', 'green']), 5

  it 'transactions should not be requested if pending less than timeout', calls 0, (done) ->
    ignoreFirst = true
    [model, sockets] = mockSocketModel '0', 'txnsSince', (ver) ->
      # A txnsSince request is sent immediately upon connecting,
      # so the first one should be ignored
      return ignoreFirst = false  if ignoreFirst
      done()
    sockets.emit 'txn', transaction.create(base: 1, id: '1.1', method: 'set', args: ['color', 'green']), 1
    sockets.emit 'txn', transaction.create(base: 3, id: '1.3', method: 'set', args: ['color', 'green']), 3
    sockets.emit 'txn', transaction.create(base: 2, id: '1.2', method: 'set', args: ['color', 'green']), 2
    setTimeout sockets._disconnect, 50
  
  it 'sub event should be sent on socket.io connect', (done) ->
    [model, sockets] = mockSocketModel '0', 'sub', (clientId, storeSubs, ver) ->
      expect(clientId).to.eql '0'
      expect(storeSubs).to.eql []
      expect(ver).to.eql 0
      sockets._disconnect()
      done()
  
  it 'test speculative value of set', ->
    model = new Model '0'
    
    previous = model.set 'color', 'green'
    expect(previous).to.equal undefined
    expect(model.get 'color').to.eql 'green'
    
    previous = model.set 'color', 'red'
    expect(previous).to.equal 'green'
    expect(model.get 'color').to.eql 'red'
    
    model.set 'info.numbers', first: 2, second: 10
    expect(model.get()).to.specEql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10
    expect(model._adapter._data).to.specEql world: {}
    
    model.set 'info.numbers.third', 13
    expect(model.get()).to.specEql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10
          third: 13
    expect(model._adapter._data).to.specEql world: {}
    
    model._removeTxn '0.1'
    model._removeTxn '0.2'
    expect(model.get()).to.specEql
      color: 'green'
      info:
        numbers:
          third: 13
    expect(model._adapter._data).to.specEql world: {}

  "speculative mutations of an existing object should not modify the adapter's underlying presentation of that object": ->
    model = new Model '0'
    model._adapter._data = world: {obj: {}}
    expect(model._adapter._data).to.specEql world: {obj: {}}
    model.set 'obj.a', 'b'
    expect(model._adapter._data).to.specEql world: {obj: {}}

  it 'test speculative value of del', ->
    model = new Model '0'
    model._adapter._data =
      world:
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10
  
    previous = model.del 'color'
    expect(previous).to.eql 'green'
    expect(model.get()).to.specEql
      info:
        numbers:
          first: 2
          second: 10

    expect(model._adapter._data).to.specEql
      world:
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10
    
    model.set 'color', 'red'
    expect(model.get()).to.specEql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10
    
    model.del 'color'
    expect(model.get()).to.specEql
      info:
        numbers:
          first: 2
          second: 10
    
    model.del 'info.numbers'
    expect(model.get()).to.specEql
      info: {}
    
    expect(model._adapter._data).to.specEql
      world:
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10
    
    # Make sure deleting something that doesn't exist isn't a problem
    model.del 'a.b.c'
    expected = [
        transaction.create(base: 0, id: '0.0', method: 'del', args: ['color'])
      , transaction.create(base:0, id: '0.1', method: 'set', args: ['color', 'red'])
      , transaction.create(base: 0, id: '0.2', method: 'del', args: ['color'])
      , transaction.create(base: 0, id: '0.3', method: 'del', args: ['info.numbers'])
      , transaction.create(base: 0, id: '0.4', method: 'del', args: ['a.b.c'])
    ]
    expected.forEach (txn) ->
      txn.emitted = true
      txn.isPrivate = false
    queue = model._txnQueue.map (id) ->
      txn = model._txns[id]
      delete txn.callback
      return txn
    expect(queue).to.eql expected

  it 'test speculative incr', ->
    model = new Model
    
    # Should be able to increment unset path
    val = model.incr 'count'
    expect(model.get 'count').to.eql 1
    expect(val).to.eql 1
    
    # Default increment should be 1
    val = model.incr 'count'
    expect(model.get 'count').to.eql 2
    expect(val).to.eql 2
    
    # Should be able to increment by another number
    val = model.incr 'count', -2
    expect(model.get 'count').to.eql 0
    expect(val).to.eql 0
    
    # Incrementing by zero should work
    val = model.incr 'count', 0
    expect(model.get 'count').to.eql 0
    expect(val).to.eql 0

  it 'test speculative push', ->
    model = new Model
    
    model.push 'colors', 'green'
    expect(model.get 'colors').to.specEql ['green']
    expect(model._adapter._data).to.specEql world: {}

  it 'model events should get emitted properly', (done) ->
    ver = 0
    [model, sockets] = mockSocketModel '0', 'txn', (txn) ->
      transaction.base txn, ++ver
      sockets.emit 'txn', txn, ver
    count = 0
    model.on 'set', '*', (path, value) ->
      expect(path).to.equal 'color'
      expect(value).to.equal 'green'
      if count is 0
        expect(model._txnQueue.length).to.eql 1
        expect(model._adapter._data).to.specEql world: {}
      else
        expect(model._txnQueue.length).to.eql 0
        expect(model._adapter._data).to.specEql world: {color: 'green'}
      expect(model.get 'color').to.equal 'green'
      count++
      sockets._disconnect()
      done()
    model.set 'color', 'green'

  it 'model events should indicate when locally emitted', (done) ->
    model = new Model
    model.on 'set', '*', (path, value, previous, local) ->
      expect(path).to.eql 'color'
      expect(value).to.eql 'green'
      expect(previous).to.equal undefined
      expect(local).to.eql true
      done()
    model.set 'color', 'green'

  it 'model events should indicate when not locally emitted', (done) ->
    [model, sockets] = mockSocketModel '0'
    model.on 'set', '*', (path, value, previous, local) ->
      expect(path).to.eql 'color'
      expect(value).to.eql 'green'
      expect(previous).to.equal undefined
      expect(local).to.eql false
      sockets._disconnect()
      done()
    sockets.emit 'txn', transaction.create(base: 1, id: '1.1', method: 'set', args: ['color', 'green']), 1

  it 'model.once should only emit once', (done) ->
    model = new Model
    model.once 'set', 'color', -> done()
    model.set 'color', 'green'
    model.set 'color', 'red'

  it 'model.once should only emit once per path', (done) ->
    model = new Model
    model.once 'set', 'color', -> done()
    model.set 'other', 3
    model.set 'color', 'green'
    model.set 'color', 'red'

  it 'model.pass should pass an object to an event listener', (done) ->
    model = new Model
    model.on 'set', 'color', (value, previous, isLocal, pass) ->
      expect(value).to.equal 'green'
      expect(previous).to.equal undefined
      expect(isLocal).to.equal true
      expect(pass).to.equal 'hi'
      done()
    model.pass('hi').set 'color', 'green'

  it 'model.pass should support setting', ->
    model = new Model
    model.pass('hi').set 'color', 'green'
    expect(model.get 'color').to.eql 'green'
    model.set 'color2', 'red'
    expect(model.get()).to.specEql
      color: 'green'
      color2: 'red'

  it 'test client emits events on receipt of a transaction iff it did not create the transaction', (done) ->
    [model, sockets] = mockSocketModel('clientA')
    eventCalled = false
    model.on 'set', 'color', (val) ->
      eventCalled = true
    txn = transaction.create(base: 1, id: 'clientA.0', method: 'set', args: ['color', 'green'])
    model._txns['clientA.0'] = txn
    model._txnQueue = ['clientA.0']
    txn.emitted = true
    sockets.emit 'txn', txn, 1
    setTimeout ->
      expect(eventCalled).to.be.false
      sockets._disconnect()
      done()
    , 50
  
  it 'forcing a model method should create a transaction with a null version', ->
    model = new Model '0'
    model.set 'color', 'green'
    model.force.set 'color', 'red'
    model.force.del 'color'
    expect(model._txns['0.0'].slice()).to.eql transaction.create base: 0, id: '0.0', method: 'set', args: ['color', 'green']
    expect(model._txns['0.1'].slice()).to.eql transaction.create base: null, id: '0.1', method: 'set', args: ['color', 'red']
    expect(model._txns['0.2'].slice()).to.eql transaction.create base: null, id: '0.2', method: 'del', args: ['color']

  it 'a forced model mutation should not result in an adapter ver of null or undefined', ->
    model = new Model '0'
    model.set 'color', 'green'
    model.force.set 'color', 'red'
    expect(model._adapter.version).to.not.be.null
    expect(model._adapter.version).to.not.be.undefined
  
  it 'model mutator methods should callback on completion', calls 2, (done) ->
    ver = 0
    [model, sockets] = mockSocketModel '0', 'txn', (txn) ->
      transaction.base txn, ++ver
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
      sockets.emit 'txnErr', 'conflict', transaction.id txn
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

  it 'model push should instantiate an undefined path to a new array and insert new members at the end', ->
    model = new Model '0'
    init = model.get 'colors'
    expect(init).to.equal undefined
    out = model.push 'colors', 'green'
    expect(out).to.eql 1
    final = model.get 'colors'
    expect(final).to.specEql ['green']

  it 'model pop should remove a member from an array', ->
    model = new Model '0'
    init = model.get 'colors'
    expect(init).to.equal undefined
    model.push 'colors', 'green'
    interim = model.get 'colors'
    expect(interim).to.specEql ['green']
    out = model.pop 'colors'
    expect(out).to.eql 'green'
    final = model.get 'colors'
    expect(final).to.specEql []

  it 'model unshift should instantiate an undefined path to a new array and insert new members at the beginning', ->
    model = new Model '0'
    init = model.get 'colors'
    expect(init).to.equal undefined
    out = model.unshift 'colors', 'green'
    expect(out).to.eql 1
    interim = model.get 'colors'
    expect(interim).to.specEql ['green']
    out = model.unshift 'colors', 'red', 'orange'
    expect(out).to.eql 3
    final = model.get 'colors'
    expect(final).to.specEql ['red', 'orange', 'green']

  it 'model shift should remove the first member from an array', ->
    model = new Model '0'
    init = model.get 'colors'
    expect(init).to.equal undefined
    out = model.unshift 'colors', 'green', 'blue'
    expect(out).to.eql 2
    interim = model.get 'colors'
    expect(interim).to.specEql ['green', 'blue']
    out = model.shift 'colors'
    expect(out).to.eql 'green'
    final = model.get 'colors'
    expect(final).to.specEql ['blue']

  it 'insert should work on an array, with a valid index', ->
    model = new Model '0'
    model.push 'colors', 'green'
    out = model.insert 'colors', 0, 'red', 'yellow'
    expect(out).to.eql 3
    expect(model.get 'colors').to.specEql ['red', 'yellow', 'green']
  
  it 'insert should work on an array index path', ->
    model = new Model '0'
    model.push 'colors', 'green'
    out = model.insert 'colors.0', 'red', 'yellow'
    expect(out).to.eql 3
    expect(model.get 'colors').to.specEql ['red', 'yellow', 'green']

  it 'remove should work on an array, with a valid index', ->
    model = new Model '0'
    model.push 'colors', 'red', 'orange', 'yellow', 'green', 'blue', 'violet'
    out = model.remove 'colors', 1, 4
    expect(out).to.specEql ['orange', 'yellow', 'green', 'blue']
    expect(model.get 'colors').to.specEql ['red', 'violet']
  
  it 'remove should work on an array index path', ->
    model = new Model '0'
    model.push 'colors', 'red', 'orange', 'yellow', 'green', 'blue', 'violet'
    out = model.remove 'colors.1', 4
    expect(out).to.specEql ['orange', 'yellow', 'green', 'blue']
    expect(model.get 'colors').to.specEql ['red', 'violet']

  it 'move should work on an array, with a valid index', ->
    model = new Model '0'
    model.push 'colors', 'red', 'orange', 'yellow', 'green'
    out = model.move 'colors', 1, 2
    expect(out).to.eql ['orange']
    expect(model.get 'colors').to.specEql ['red', 'yellow', 'orange', 'green']
    out = model.move 'colors', 0, 3
    expect(out).to.eql ['red']
    expect(model.get 'colors').to.specEql ['yellow', 'orange', 'green', 'red']
    out = model.move 'colors', 0, 0
    expect(out).to.eql ['yellow']
    expect(model.get 'colors').to.specEql ['yellow', 'orange', 'green', 'red']
  
  it 'move should work on an array index path', ->
    model = new Model '0'
    model.push 'colors', 'red', 'orange', 'yellow', 'green'
    out = model.move 'colors.1', 2
    expect(out).to.eql ['orange']
    expect(model.get 'colors').to.specEql ['red', 'yellow', 'orange', 'green']
    out = model.move 'colors.0', 3
    expect(out).to.eql ['red']
    expect(model.get 'colors').to.specEql ['yellow', 'orange', 'green', 'red']
    out = model.move 'colors.0', 0
    expect(out).to.eql ['yellow']
    expect(model.get 'colors').to.specEql ['yellow', 'orange', 'green', 'red']

  it 'supports an id method for creating a guid', ->
    model = new Model '0'
    id00 = model.id()
    id01 = model.id()

    model = new Model '1'
    id10 = model.id()

    expect(id00).to.be.a 'string'
    expect(id01).to.be.a 'string'
    expect(id10).to.be.a 'string'

    expect(id00).to.not.eql id01
    expect(id00).to.not.eql id10
