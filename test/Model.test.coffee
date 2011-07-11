Model = require 'Model'
wrapTest = require('./util').wrapTest
mockSocketModel = require('./util/model').mockSocketModel

module.exports =
  
  'test get': ->
    model = new Model
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
    model = new Model
    model._data.should.eql {}
    
    model._set 'color', 'green'
    model._data.should.eql color: 'green'
    
    model._set 'info.numbers', first: 2, second: 10
    model._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model._set 'info', 'new'
    model._data.should.eql
      color: 'green'
      info: 'new'
  
  'test internal del': ->
    model = new Model
    model._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model._del 'color'
    model._data.should.eql
      info:
        numbers:
          first: 2
          second: 10
    
    model._del 'info.numbers'
    model._data.should.eql
      info: {}
  
  'test internal creation of client transactions on set': ->
    model = new Model
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
    [sockets, model] = mockSocketModel()
    sockets.emit 'txn', [1, 'server0.0', 'set', 'color', 'green']
    model.get('color').should.eql 'green'
    model._base.should.eql 1
  
  'test client sends transaction on set': wrapTest (done) ->
    [sockets, model] = mockSocketModel 'client0', (txn) ->
      txn.should.eql [0, 'client0.0', 'set', 'color', 'green']
      done()
  
    model.set 'color', 'green'
  
  'test client set roundtrip with server echoing transaction': wrapTest (done) ->
    [sockets, model] = mockSocketModel 'client0', (txn) ->
      sockets.emit 'txn', txn
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
  
  'test client del roundtrip with server echoing transaction': wrapTest (done) ->
    [sockets, model] = mockSocketModel 'client0', (txn) ->
      sockets.emit 'txn', txn
      model._data.should.eql {}
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      done()
  
    model._data = color: 'green'
    model.del 'color'
    model._txnQueue.should.eql ['client0.0']
    model._txns.should.eql
      'client0.0':
        op: ['del', 'color']
        base: 0
        sent: true
  
  'test transaction is removed after failure': wrapTest (done) ->
    [sockets, model] = mockSocketModel 'client0', (txn) ->
      sockets.emit 'txnFail', 'client0.0'
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
    model = new Model
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
  
  'test speculative value of del': ->
    model = new Model
    model._clientId = 'client0'
    model._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
  
    model.del 'color'
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
    
    model.del 'color'
    model.get().should.protoEql
      info:
        numbers:
          first: 2
          second: 10
    
    model.del 'info.numbers'
    model.get().should.protoEql
      info: {}
    
    model._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
  
  'test internal creation of model event subscriptions': ->
    model = new Model
    model.on 'set', pattern for pattern in [
      'color'
      '*'
      '*.color.*'
    ]
    sources = [
      '^color$'
      '^([^\\.]+)$'
      '^([^\\.]+)\\.color\\.([^\\.]+)$'
    ]
    matches = [
      ['color']
      ['any-thing']
      ['x.color.y', 'any-thing.color.x']
    ]
    nonMatches = [
      ['', 'xcolor', 'colorx', '.color', 'color.', 'x.color', 'color.x']
      ['', 'x.y', '.x', 'x.']
      ['x.colorx.y', 'x.xcolor.y', 'x.color', 'color.y',
        '.color.y', 'x.color.', 'a.x.color.y', 'x.color.y.b']
    ]
    for sub, i in model._subs['set']
      re = sub[0]
      re.source.should.equal sources[i]
      re.test(match).should.be.true for match in matches[i]
      re.test(nonMatch).should.be.false for nonMatch in nonMatches[i]

  'test that model events get emitted properly': wrapTest (done) ->
    [sockets, model] = mockSocketModel 'client0', (txn) ->
      sockets.emit 'txn', txn
    count = 0
    model.on 'set', '*', (path, value) ->
      path.should.equal 'color'
      value.should.equal 'green'
      if count is 0
        model._txnQueue.length.should.eql 1
        model._data.should.eql {}
      else
        model._txnQueue.length.should.eql 0
        model._data.should.eql color: 'green'
      model.get('color').should.equal 'green'
      count++
      done()
    model.set 'color', 'green'
  , 2
