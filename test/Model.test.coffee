wrapTest = require('./util').wrapTest
modelUtil = require './util/model'
newModel = modelUtil.newModel
mockSocketModel = modelUtil.mockSocketModel

module.exports =
  'test get on server': ->
    model = newModel 'server'
    model.store.adapter._data.should.eql {}
    model._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model.get 'color', (err, val, ver, doc) ->
      val.should.equal 'green'
      model.get 'info.numbers', (err, val, ver, doc) ->
        val.should.eql first: 2, second: 10

  'test get in browser': ->
    model = newModel 'browser'
    model._data.should.eql {}
    model._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model.get('color').should.eql 'green'
    model.get('info.numbers').should.eql first: 2, second: 10
    model.get().should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
  
  'test internal set': ->
    model = newModel 'server'
    model._data.should.eql {}
    
    model._setters.set 'color', 'green'
    model._data.should.eql color: 'green'
    
    model._setters.set 'info.numbers', first: 2, second: 10
    model._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model._setters.set 'info', 'new'
    model._data.should.eql
      color: 'green'
      info: 'new'
  
  'test internal delete': ->
    model = newModel 'server'
    model._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model._setters.del 'color'
    model._data.should.eql
      info:
        numbers:
          first: 2
          second: 10
    
    model._setters.del 'info.numbers'
    model._data.should.eql
      info: {}
  
  'test internal creation of client transactions on set': ->
    model = newModel 'browser'
    model._clientId = 'client0'
    
    model.set 'color', 'green'
    model._txns.should.eql
      'client0.0':
        op: ['set', 'color', 'green']
        base: 0
        sent: false
    model._txnQueue.should.eql ['client0.0']
    
    model.set 'count', 0
    model._txns.should.eql
      'client0.0':
        op: ['set', 'color', 'green']
        base: 0
        sent: false
      'client0.1':
        op: ['set', 'count', '0']
        base: 0
        sent: false
    model._txnQueue.should.eql ['client0.0', 'client0.1']
  
  'test client performs set on receipt of message': ->
    [serverSocket, model] = mockSocketModel()
    
    serverSocket.broadcast ['txn', [1, 'server0.0', 'set', 'color', 'green']]
    model.get('color').should.eql 'green'
    model._base.should.eql 1
  
  'test client sends transaction on set': wrapTest (done) ->
    [serverSocket, model] = mockSocketModel 'client0', (message) ->
      message.should.eql ['txn', [0, 'client0.0', 'set', 'color', 'green']]
      done()
  
    model.set 'color', 'green'
  
  'test client set roundtrip with server echoing transaction': wrapTest (done) ->
    [serverSocket, model] = mockSocketModel 'client0', (message) ->
      serverSocket.broadcast message
      model.get('color').should.eql 'green'
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      done()
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['client0.0']
    model._txns.should.eql
      'client0.0':
        op: ['set', 'color', 'green']
        base: 0
        sent: true
  
  'test client delete roundtrip with server echoing transaction': wrapTest (done) ->
    [serverSocket, model] = mockSocketModel 'client0', (message) ->
      serverSocket.broadcast message
      model._data.should.eql {}
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      done()
  
    model._data = color: 'green'
    model.delete 'color'
    model._txnQueue.should.eql ['client0.0']
    model._txns.should.eql
      'client0.0':
        op: ['del', 'color']
        base: 0
        sent: true
  
  'test transaction is removed after failure': wrapTest (done) ->
    [serverSocket, model] = mockSocketModel 'client0', (message) ->
      serverSocket.broadcast ['txnFail', 'client0.0']
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      done()
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['client0.0']
    model._txns.should.eql
      'client0.0':
        op: ['set', 'color', 'green']
        base: 0
        sent: true
  
  'test speculative value of set': ->
    model = newModel 'browser'
    model._clientId = 'client0'
    
    model.set 'color', 'green'
    model.get('color').should.eql 'green'
    
    model.set 'color', 'red'
    model.get('color').should.eql 'red'
    
    model.set 'info.numbers', first: 2, second: 10
    model.get().should.eql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10
    
    model.set 'info.numbers.third', 13
    model.get().should.eql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10
          third: 13
    
    model._data.should.eql {}
    
    model._removeTxn 'client0.1'
    model._removeTxn 'client0.2'
    model.get().should.eql
      color: 'green'
      info:
        numbers:
          third: 13
  
  'test speculative value of delete': ->
    model = newModel 'browser'
    model._clientId = 'client0'
    model._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10

    model.delete 'color'
    model.get().should.protoEql
      info:
        numbers:
          first: 2
          second: 10
    
    model.set 'color', 'red'
    model.get().should.protoEql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10
    
    model.delete 'color'
    model.get().should.protoEql
      info:
        numbers:
          first: 2
          second: 10
    
    model.delete 'info.numbers'
    model.get().should.protoEql
      info: {}
    
    model._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
