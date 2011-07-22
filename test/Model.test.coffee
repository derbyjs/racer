Model = require 'Model'
util = require './util'
wrapTest = util.wrapTest
protoInspect = util.protoInspect

mockSocketModel = require('./util/model').mockSocketModel

module.exports =
  
  'test internal creation of client transactions on set': ->
    model = new Model
    model._clientId = '0'
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['0.0']
    model._txns['0.0'].slice().should.eql [0, '0.0', 'set', 'color', 'green']
    
    model.set 'count', 0
    model._txnQueue.should.eql ['0.0', '0.1']
    model._txns['0.0'].slice().should.eql [0, '0.0', 'set', 'color', 'green']
    model._txns['0.1'].slice().should.eql [0, '0.1', 'set', 'count', '0']
  
  'test client performs set on receipt of message': ->
    [sockets, model] = mockSocketModel()
    sockets.emit 'txn', [1, 'server0.0', 'set', 'color', 'green']
    model.get('color').should.eql 'green'
    model._adapter.ver.should.eql 1
    sockets._disconnect()
  
  'test client set roundtrip with server echoing transaction': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn.should.eql [0, '0.0', 'set', 'color', 'green']
      txn[0]++
      sockets.emit 'txn', txn
      model.get('color').should.eql 'green'
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      sockets._disconnect()
      done()
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['0.0']
  
  'test client del roundtrip with server echoing transaction': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn.should.eql [0, '0.0', 'del', 'color']
      txn[0]++
      sockets.emit 'txn', txn
      model._adapter._data.should.eql {}
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      sockets._disconnect()
      done()
  
    model._adapter._data = color: 'green'
    model.del 'color'
    model._txnQueue.should.eql ['0.0']
  
  'setting on a private path should only be applied locally': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'txn', done
    model.set '_color', 'green'
    model.get('_color').should.eql 'green'
    model._txnQueue.should.eql []
  , 0
  
  'transactions should be removed after failure': wrapTest (done) ->
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      sockets.emit 'txnFail', '0.0'
      model._txnQueue.should.eql []
      model._txns.should.eql {}
      sockets._disconnect()
      done()
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['0.0']
  
  'transactions received out of order should be applied in order': ->
    [sockets, model] = mockSocketModel()
    sockets.emit 'txn', [1, '_.0', 'set', 'color', 'green']
    model.get('color').should.eql 'green'
    
    sockets.emit 'txn', [3, '_.0', 'set', 'color', 'red']
    model.get('color').should.eql 'green'
    
    sockets.emit 'txn', [2, '_.0', 'set', 'number', 7]
    model.get('color').should.eql 'red'
    model.get('number').should.eql 7
    sockets._disconnect()
  
  'new transactions should be requested on socket.io connect': wrapTest (done) ->
    [sockets, model] = mockSocketModel '', 'txnsSince', (txnsSince) ->
      txnsSince.should.eql 1
      sockets._disconnect()
      done()
  
  'transactions should not be requested if pending less than timeout': wrapTest (done) ->
    [sockets, model] = mockSocketModel '', 'txnsSince', (txnsSince) ->
      txnsSince.should.eql 1
      sockets._disconnect()
      done()
    sockets.emit 'txn', [1, '_.0', 'set', 'color', 'green']
    sockets.emit 'txn', [3, '_.0', 'set', 'color', 'red']
    sockets.emit 'txn', [2, '_.0', 'set', 'color', 'blue']
  
  'test speculative value of set': ->
    model = new Model
    model._clientId = '0'
    
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
    
    model._adapter._data.should.eql {}
    
    model._removeTxn '0.1'
    model._removeTxn '0.2'
    model.get().should.eql
      color: 'green'
      info:
        numbers:
          third: 13
  
  'test speculative value of del': ->
    model = new Model
    model._clientId = '0'
    model._adapter._data =
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
    
    model._adapter._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
  
  'test getting model references': ->
    model = new Model
    model._adapter._data =
      info:
        numbers:
          first: 2
          second: 10
      numbers: model.ref 'info.numbers'
      numKey: 'first'
      number: model.ref 'numbers', 'numKey'
    
    # Test non-keyed object reference
    model.get('numbers').should.eql first: 2, second: 10
    # Test property below object reference
    model.get('numbers.second').should.eql 10
    # Test keyed object reference
    model.get('number').should.eql 2
    
    # Test changing key object reference with speculative set
    model.set 'numKey', 'second'
    model.get('number').should.eql 10
    # Test changing referenced object wtih speculative set
    model.set 'info', numbers: {first: 3, second: 7}
    model.get('number').should.eql 7
  
  'test setting to model references': ->
    model = new Model
    
    # Setting a reference before a key should make a record of the key but
    # not the reference
    model.set 'color', model.ref 'colors', 'selected'
    model.get().should.protoEql
      color: model.ref 'colors', 'selected'
      $keys: {selected: $: 'color$colors$selected': ['color', 'colors', 'selected']}
    
    # Setting a key value should update the reference
    model.set 'selected', 'blue'
    model.get().should.protoEql
      color: model.ref 'colors', 'selected'
      selected: 'blue'
      $keys: {selected: $: 'color$colors$selected': ['color', 'colors', 'selected']}
      $refs: {colors: blue: $: 'color$colors$selected': ['color', 'colors', 'selected']}
    
    # Setting a property on a reference should update the referenced object
    model.set 'color.hex', '#0f0'
    model.get().should.protoEql
      colors:
        blue:
          hex: '#0f0'
      color: model.ref 'colors', 'selected'
      selected: 'blue'
      $keys: {selected: $: 'color$colors$selected': ['color', 'colors', 'selected']}
      $refs: {colors: blue: $: 'color$colors$selected': ['color', 'colors', 'selected']}
    
    # Setting on a path that is currently a reference should modify the
    # reference, similar to setting an object reference in Javascript
    model.set 'color', model.ref 'colors.blue'
    model.get().should.protoEql
      colors:
        blue:
          hex: '#0f0'
      color: model.ref 'colors.blue'
      selected: 'blue'
      $keys: {selected: $: 'color$colors$selected': ['color', 'colors', 'selected']}
      $refs:
        colors:
          blue:
            $:
              'color$colors$selected': ['color', 'colors', 'selected']
              'color$colors.blue': ['color', 'colors.blue']
    
    # Test setting on a non-keyed reference
    model.set 'color.compliment', 'yellow'
    model.get().should.protoEql
      colors:
        blue:
          hex: '#0f0'
          compliment: 'yellow'
      color: model.ref 'colors.blue'
      selected: 'blue'
      $keys: {selected: $: 'color$colors$selected': ['color', 'colors', 'selected']}
      $refs:
        colors:
          blue:
            $:
              'color$colors$selected': ['color', 'colors', 'selected']
              'color$colors.blue': ['color', 'colors.blue']
  
  'transactions should dereference paths': wrapTest (done) ->
    count = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn.should.eql expected[count++]
      sockets._disconnect()
      done()
    expected = [
      [0, '0.0', 'set', 'color', model.ref 'colors.green']
      [0, '0.1', 'set', 'colors.green.hex', '#0f0']
    ]
    model.set 'color', model.ref 'colors.green'
    model.set 'color.hex', '#0f0'
  , 2
  
  'test internal creation of model event subscriptions': ->
    model = new Model
    model.on 'set', pattern for pattern in [
      'color'
      '*'
      '*.color.*'
      '**'
      '**.color.**'
      /^(colors?)$/
    ]
    sources = [
      '^color$'
      '^([^\\.]+)$'
      '^([^\\.]+)\\.color\\.([^\\.]+)$'
      '^(.+)$'
      '^(.+?)\\.color\\.(.+)$'
      '^(colors?)$'
    ]
    matches = [
      ['color': []]
      ['any-thing': ['any-thing']]
      ['x.color.y': ['x', 'y'],
       'any-thing.color.x': ['any-thing', 'x']]
      ['x': ['x'],
       'x.y': ['x.y']]
      ['x.color.y': ['x', 'y'],
       'a.b-c.color.x.y': ['a.b-c', 'x.y']]
      ['color': ['color'],
       'colors': ['colors']]
    ]
    nonMatches = [
      ['', 'xcolor', 'colorx', '.color', 'color.', 'x.color', 'color.x']
      ['', 'x.y', '.x', 'x.']
      ['x.colorx.y', 'x.xcolor.y', 'x.color', 'color.y',
       '.color.y', 'x.color.', 'a.x.color.y', 'x.color.y.b']
      ['']
      ['x.colorx.y', 'x.xcolor.y', 'x.color', 'color.y', '.color.y', 'x.color.']
      ['colorx']
    ]
    for sub, i in model._subs['set']
      re = sub[0]
      re.source.should.equal sources[i]
      for obj in matches[i]
        for match, captures of obj
          re.exec(match).slice(1).should.eql captures
      re.test(nonMatch).should.be.false for nonMatch in nonMatches[i]
  
  'model events should get emitted properly': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn[0] = ++ver
      sockets.emit 'txn', txn
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
  , 2
  
  'models events should be emitted on a reference': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn[0] = ++ver
      sockets.emit 'txn', txn
    model.on 'set', 'color.*', (prop, value) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      sockets._disconnect()
      done()
    model.set 'color', model.ref 'colors.green'
    model.set 'color.hex', '#0f0'
  , 2
  