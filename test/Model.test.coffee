require('../src/util/debug')('notifyPointers')
Model = require 'Model'
should = require 'should'
util = require './util'
transaction = require 'transaction'
wrapTest = util.wrapTest

mockSocketModel = require('./util/model').mockSocketModel

module.exports =
  
  'test internal creation of client transactions on set': ->
    model = new Model '0'
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['0.0']
    model._txns['0.0'].slice().should.eql transaction.create base: 0, id: '0.0', method: 'set', args: ['color', 'green']
    
    model.set 'count', 0
    model._txnQueue.should.eql ['0.0', '0.1']
    model._txns['0.0'].slice().should.eql transaction.create base: 0, id: '0.0', method: 'set', args: ['color', 'green']
    model._txns['0.1'].slice().should.eql transaction.create base: 0, id: '0.1', method: 'set', args: ['count', '0']
  
  'test client performs set on receipt of message': ->
    [sockets, model] = mockSocketModel()
    sockets.emit 'txn', transaction.create(base: 1, id: 'server0.0', method: 'set', args: ['color', 'green']), 1
    model.get('color').should.eql 'green'
    model._adapter.ver.should.eql 1
    sockets._disconnect()
  
  'test client set roundtrip with server echoing transaction': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn.should.eql transaction.create base: 0, id: '0.0', method: 'set', args: ['color', 'green']
      transaction.base txn, ++ver
      sockets.emit 'txn', txn, ver
      model.get('color').should.eql 'green'
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      sockets._disconnect()
      done()
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['0.0']
  
  'test client del roundtrip with server echoing transaction': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn.should.eql transaction.create base: 0, id: '0.0', method: 'del', args: ['color']
      transaction.base txn, ++ver
      sockets.emit 'txn', txn, ver
      model._adapter._data.should.eql {}
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      sockets._disconnect()
      done()
  
    model._adapter._data = color: 'green'
    model.del 'color'
    model._txnQueue.should.eql ['0.0']

  'test client push roundtrip with server echoing transaction': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn.should.eql transaction.create base: 0, id: '0.0', method: 'push', args: ['colors', 'red']
      transaction.base txn, ++ver
      sockets.emit 'txn', txn, ver
      model.get('colors').should.eql ['red']
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      sockets._disconnect()
      done()
  
    model.push 'colors', 'red'
    model._txnQueue.should.eql ['0.0']
  
  'setting on a private path should only be applied locally': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'txn', done
    model.set '_color', 'green'
    model.get('_color').should.eql 'green'
    model._txnQueue.should.eql []
    sockets._disconnect()
  , 0
  
  'transactions should be removed after failure': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      sockets.emit 'txnErr', 'conflict', '0.0'
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      sockets._disconnect()
      done()
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['0.0']
  
  'transactions received out of order should be applied in order': ->
    [sockets, model] = mockSocketModel()
    sockets.emit 'txn', transaction.create(base: 1, id: '_.0', method: 'set', args: ['color', 'green']), 1
    model.get('color').should.eql 'green'
    
    sockets.emit 'txn', transaction.create(base: 3, id: '_.0', method: 'set', args: ['color', 'red']), 3
    model.get('color').should.eql 'green'
    
    sockets.emit 'txn', transaction.create(base: 2, id: '_.0', method: 'set', args: ['number', 7]), 2
    model.get('color').should.eql 'red'
    model.get('number').should.eql 7
    sockets._disconnect()
  
  'duplicate transaction versions should not be applied': ->
    [sockets, model] = mockSocketModel()
    sockets.emit 'txn', transaction.create(base: 1, id: '_.0', method: 'push', args: ['colors', 'green']), 1
    sockets.emit 'txn', transaction.create(base: 1, id: '_.0', method: 'push', args: ['colors', 'green']), 2
    model.get('colors').should.eql ['green']
    sockets._disconnect()
  
  'transactions should be requested if pending longer than timeout': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'txnsSince', (txnsSince) ->
      txnsSince.should.eql 3
      sockets._disconnect()
      done()
    sockets.emit 'txn', transaction.create(base: 1, id: '1.1', method: 'set', args: ['color', 'green']), 1
    sockets.emit 'txn', transaction.create(base: 2, id: '1.2', method: 'set', args: ['color', 'green']), 2
    sockets.emit 'txn', transaction.create(base: 4, id: '1.4', method: 'set', args: ['color', 'green']), 4
    sockets.emit 'txn', transaction.create(base: 5, id: '1.5', method: 'set', args: ['color', 'green']), 5

  'transactions should not be requested if pending less than timeout': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'txnsSince', done
    sockets.emit 'txn', transaction.create(base: 1, id: '1.1', method: 'set', args: ['color', 'green']), 1
    sockets.emit 'txn', transaction.create(base: 3, id: '1.3', method: 'set', args: ['color', 'green']), 3
    sockets.emit 'txn', transaction.create(base: 2, id: '1.2', method: 'set', args: ['color', 'green']), 2
    setTimeout sockets._disconnect, 100
  , 0
  
  'sub event should be sent on socket.io connect': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'sub', (clientId, storeSubs, ver) ->
      clientId.should.eql '0'
      storeSubs.should.eql []
      ver.should.eql 0
      sockets._disconnect()
      done()
  
  'test speculative value of set': ->
    model = new Model '0'
    
    model.set 'color', 'green'
    model.get('color').should.eql 'green'
    
    model.set 'color', 'red'
    model.get('color').should.eql 'red'
    
    model.set 'info.numbers', first: 2, second: 10
    model.get().should.specEql
      color: 'red'
      info:
        numbers:
          # No `_proto: true` here because 'info.numbers' was set to an object
          first: 2
          second: 10
    model._adapter._data.should.eql {}
    
    model.set 'info.numbers.third', 13
    model.get().should.specEql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10
          third: 13
    model._adapter._data.should.eql {}
    
    model._removeTxn '0.1'
    model._removeTxn '0.2'
    model.get().should.specEql
      color: 'green'
      info:
        _proto: true
        numbers:
          _proto: true
          third: 13
    model._adapter._data.should.eql {}

  "speculative mutations of an existing object should not modify the adapter's underlying presentation of that object": ->
    model = new Model '0'
    model._adapter._data = obj: {}
    model._adapter._data.should.eql obj: {}
    model.set 'obj.a', 'b'
    model._adapter._data.should.eql obj: {}

  'test speculative value of del': ->
    model = new Model '0'
    model._adapter._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
  
    model.del 'color'
    model.get().should.specEql
      info:
        numbers:
          first: 2
          second: 10

    model._adapter._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model.set 'color', 'red'
    model.get().should.specEql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10
    
    model.del 'color'
    model.get().should.specEql
      info:
        numbers:
          first: 2
          second: 10
    
    model.del 'info.numbers'
    model.get().should.specEql
      info: {}
    
    model._adapter._data.should.eql
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
    expected.forEach (txn) -> txn.emitted = true
    model._txnQueue.map((id) ->
      txn = model._txns[id]
      delete txn.callback
      txn
    ).should.eql expected

  'test speculative incr': ->
    model = new Model
    
    # Should be able to increment unset path
    val = model.incr 'count'
    model.get('count').should.eql 1
    val.should.eql 1
    
    # Default increment should be 1
    val = model.incr 'count'
    model.get('count').should.eql 2
    val.should.eql 2
    
    # Should be able to increment by another number
    val = model.incr 'count', -2
    model.get('count').should.eql 0
    val.should.eql 0
    
    # Incrementing by zero should work
    val = model.incr 'count', 0
    model.get('count').should.eql 0
    val.should.eql 0

  'test speculative push': ->
    model = new Model
    
    model.push 'colors', 'green'
    model.get('colors').should.specEql ['green']
    model._adapter._data.should.eql {}

  'model events should get emitted properly': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      transaction.base txn, ++ver
      sockets.emit 'txn', txn, ver
    count = 0
    model.on 'set', '*', (path, value) ->
      path.should.equal 'color'
      value.should.equal 'green'
      if count is 0
        model._txnQueue.length.should.eql 1
        model._adapter._data.should.eql {}
      else
        model._txnQueue.length.should.eql 0
        model._adapter._data.should.eql color: 'green'
      model.get('color').should.equal 'green'
      count++
      sockets._disconnect()
      done()
    model.set 'color', 'green'
  , 1

  'model.once should only emit once': wrapTest (done) ->
    model = new Model
    
    model.once 'set', 'color', done
    model.set 'color', 'green'
    model.set 'color', 'red'
  , 1

  'model.once should only emit once per path': wrapTest (done) ->
    model = new Model
    
    model.once 'set', 'color', done
    model.set 'other', 3
    model.set 'color', 'green'
    model.set 'color', 'red'
  , 1

  'test client emits events on receipt of a transaction iff it did not create the transaction': wrapTest (done) ->
    [sockets, model] = mockSocketModel('clientA')
    eventCalled = false
    model.on 'set', 'color', (val) ->
      eventCalled = true
    txn = transaction.create(base: 1, id: 'clientA.0', method: 'set', args: ['color', 'green'])
    model._txns['clientA.0'] = txn
    model._txnQueue = ['clientA.0']
    txn.emitted = true
    sockets.emit 'txn', txn, 1
    setTimeout ->
      eventCalled.should.be.false
      sockets._disconnect()
      done()
    , 200
  , 1
  
  'forcing a model method should create a transaction with a null version': ->
    model = new Model '0'
    model.set 'color', 'green'
    model.force.set 'color', 'red'
    model.force.del 'color'
    model._txns['0.0'].slice().should.eql transaction.create base: 0, id: '0.0', method: 'set', args: ['color', 'green']
    model._txns['0.1'].slice().should.eql transaction.create base: null, id: '0.1', method: 'set', args: ['color', 'red']
    model._txns['0.2'].slice().should.eql transaction.create base: null, id: '0.2', method: 'del', args: ['color']

  'a forced model mutation should not result in an adapter ver of null or undefined': ->
    model = new Model '0'
    model.set 'color', 'green'
    model.force.set 'color', 'red'
    model._adapter.ver.should.not.be.null
    model._adapter.ver.should.not.be.undefined
  
  'model mutator methods should callback on completion': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      transaction.base txn, ++ver
      sockets.emit 'txn', txn
      sockets._disconnect()
    model.set 'color', 'green', (err, path, value) ->
      should.equal null, err
      path.should.equal 'color'
      value.should.equal 'green'
      done()
    model.del 'color', (err, path) ->
      should.equal null, err
      path.should.equal 'color'
      done()
  , 2
  
  'model mutator methods should callback with error on confict': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      sockets.emit 'txnErr', 'conflict', transaction.id txn
      sockets._disconnect()
    model.set 'color', 'green', (err, path, value) ->
      err.should.equal 'conflict'
      path.should.equal 'color'
      value.should.equal 'green'
      done()
    model.del 'color', (err, path) ->
      err.should.equal 'conflict'
      path.should.equal 'color'
      done()
  , 2

  'model push should instantiate an undefined path to a new array and insert new members at the end': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'green'
    final = model.get 'colors'
    final.should.specEql ['green']

#  'model push should return the length of the speculative array': ->
#    model = new Model '0'
#    len = model.push 'color', 'green'
#    len.should.equal 1

  'model pop should remove a member from an array': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'green'
    interim = model.get 'colors'
    interim.should.specEql ['green']
    model.pop 'colors'
    final = model.get 'colors'
    final.should.specEql []

#  'model pop should return the member it removed': ->
#    model = new Model '0'
#    model.push 'colors', 'green'
#    rem = model.pop()
#    rem.should.equal 'green'

  'model unshift should instantiate an undefined path to a new array and insert new members at the beginning': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.unshift 'colors', 'green'
    interim = model.get 'colors'
    interim.should.specEql ['green']
    model.unshift 'colors', 'red', 'orange'
    final = model.get 'colors'
    final.should.specEql ['red', 'orange', 'green']

  # TODO Test return value of unshift

  'model shift should remove the first member from an array': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.unshift 'colors', 'green', 'blue'
    interim = model.get 'colors'
    interim.should.specEql ['green', 'blue']
    model.shift 'colors'
    final = model.get 'colors'
    final.should.specEql ['blue']

  'model insertAfter should work on an array, with a valid index': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'green'
    interim = model.get 'colors'
    interim.should.specEql ['green']
    model.insertAfter 'colors', 0, 'red'
    final = model.get 'colors'
    final.should.specEql ['green', 'red']

  # TODO Test return value of insertAfter

  'model insertBefore should work on an array, with a valid index': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'green'
    interim = model.get 'colors'
    interim.should.specEql ['green']
    model.insertBefore 'colors', 0, 'red'
    final = model.get 'colors'
    final.should.specEql ['red', 'green']

  # TODO Test return value of insertBefore

  'model remove should work on an array, with a valid index': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'red', 'orange', 'yellow', 'green', 'blue', 'violet'
    interim = model.get 'colors'
    interim.should.specEql ['red', 'orange', 'yellow', 'green', 'blue', 'violet']
    model.remove 'colors', 1, 4
    final = model.get 'colors'
    final.should.specEql ['red', 'violet']

  # TODO Test return value of remove

  'model splice should work on an array, just like JS Array::splice': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'red', 'orange', 'yellow', 'green', 'blue', 'violet'
    interim = model.get 'colors'
    interim.should.specEql ['red', 'orange', 'yellow', 'green', 'blue', 'violet']
    model.splice 'colors', 1, 4, 'oak'
    final = model.get 'colors'
    final.should.specEql ['red', 'oak', 'violet']

  # TODO Test return value of splice
