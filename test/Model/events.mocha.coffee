{expect} = require '../util'
transaction = require '../../lib/transaction'
{mockSocketModel, BrowserModel: Model} = require '../util/model'

describe 'Model events', ->

  it 'model events should get emitted properly', (done) ->
    ver = 0
    [model, sockets] = mockSocketModel '0', 'txn', (txn) ->
      transaction.setVer txn, ++ver
      sockets.emit 'txn', txn, ver
    count = 0
    model.on 'set', '*', (path, value) ->
      expect(path).to.equal 'color'
      expect(value).to.equal 'green'
      if count is 0
        expect(model._txnQueue.length).to.eql 1
        expect(model._memory._data).to.specEql world: {}
      else
        expect(model._txnQueue.length).to.eql 0
        expect(model._memory._data).to.specEql world: {color: 'green'}
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

  it 'model events should be emitted property on a private path', (done) ->
    model = new Model
    model.on 'set', '*', (path, value, previous, local) ->
      expect(path).to.eql '_color'
      expect(value).to.eql 'green'
      expect(previous).to.equal undefined
      expect(local).to.eql true
      done()
    model.set '_color', 'green'

  it 'model events should indicate when not locally emitted', (done) ->
    [model, sockets] = mockSocketModel '0'
    model.on 'set', '*', (path, value, previous, local) ->
      expect(path).to.eql 'color'
      expect(value).to.eql 'green'
      expect(previous).to.equal undefined
      expect(local).to.eql false
      sockets._disconnect()
      done()
    sockets.emit 'txn', transaction.create(ver: 1, id: '1.1', method: 'set', args: ['color', 'green']), 1

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
    txn = transaction.create(ver: 1, id: 'clientA.0', method: 'set', args: ['color', 'green'])
    model._txns['clientA.0'] = txn
    model._txnQueue = ['clientA.0']
    txn.emitted = true
    sockets.emit 'txn', txn, 1
    setTimeout ->
      expect(eventCalled).to.be.false
      sockets._disconnect()
      done()
    , 50
