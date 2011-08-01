Model = require 'Model'
should = require 'should'
util = require './util'
transaction = require 'transaction'
wrapTest = util.wrapTest
protoInspect = util.protoInspect

mockSocketModel = require('./util/model').mockSocketModel

module.exports =
  
  'test internal creation of client transactions on set': ->
    model = new Model '0'
    
    model.set 'color', 'green'
    model._txnQueue.should.eql ['0.0']
    model._txns['0.0'].slice().should.eql [0, '0.0', 'set', 'color', 'green']
    
    model.set 'count', 0
    model._txnQueue.should.eql ['0.0', '0.1']
    model._txns['0.0'].slice().should.eql [0, '0.0', 'set', 'color', 'green']
    model._txns['0.1'].slice().should.eql [0, '0.1', 'set', 'count', '0']
  
  'test client performs set on receipt of message': ->
    [sockets, model] = mockSocketModel()
    sockets.emit 'txn', [1, 'server0.0', 'set', 'color', 'green'], 1
    model.get('color').should.eql 'green'
    model._adapter.ver.should.eql 1
    sockets._disconnect()
  
  'test client set roundtrip with server echoing transaction': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn.should.eql [0, '0.0', 'set', 'color', 'green']
      txn[0] = ++ver
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
      txn.should.eql [0, '0.0', 'del', 'color']
      txn[0] = ++ver
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
      txn.should.eql [0, '0.0', 'push', 'colors', 'red']
      txn[0] = ++ver
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
    sockets.emit 'txn', [1, '_.0', 'set', 'color', 'green'], 1
    model.get('color').should.eql 'green'
    
    sockets.emit 'txn', [3, '_.0', 'set', 'color', 'red'], 3
    model.get('color').should.eql 'green'
    
    sockets.emit 'txn', [2, '_.0', 'set', 'number', 7], 2
    model.get('color').should.eql 'red'
    model.get('number').should.eql 7
    sockets._disconnect()
  
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
    model = new Model '0'
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
    
    # Make sure deleting something that doesn't exist isn't a problem
    model.del 'a.b.c'
  
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
      $keys: {selected: $: 'color': ['colors', 'selected'] }
    
    # Setting a key value should update the reference
    model.set 'selected', 'blue'
    model.get().should.protoEql
      color: model.ref 'colors', 'selected'
      selected: 'blue'
      $keys: {selected: $: 'color': ['colors', 'selected'] }
      $refs: {colors: blue: $: 'color': ['colors', 'selected'] }
    
    # Setting a property on a reference should update the referenced object
    model.set 'color.hex', '#0f0'
    model.get().should.protoEql
      colors:
        blue:
          hex: '#0f0'
      color: model.ref 'colors', 'selected'
      selected: 'blue'
      $keys: {selected: $: 'color': ['colors', 'selected'] }
      $refs: {colors: blue: $: 'color': ['colors', 'selected'] }
    
    # Setting on a path that is currently a reference should modify the
    # reference, similar to setting an object reference in Javascript
    model.set 'color', model.ref 'colors.blue'
    model.get().should.protoEql
      colors:
        blue:
          hex: '#0f0'
      color: model.ref 'colors.blue'
      selected: 'blue'
      $keys: {}
      $refs: {colors: blue: $: color: ['colors.blue', undefined] }

    # Test setting on a non-keyed reference
    model.set 'color.compliment', 'yellow'
    model.get().should.protoEql
      colors:
        blue:
          hex: '#0f0'
          compliment: 'yellow'
      color: model.ref 'colors.blue'
      selected: 'blue'
      $keys: {}
      $refs: {colors: blue: $: color: ['colors.blue'] }
  
  'test getting and setting on a reference pointing to an undefined location': ->
    model = new Model
    
    model.set 'color', model.ref 'green'
    should.equal undefined, model.get 'color'
    should.equal undefined, model.get 'color.hex'
    
    model.set 'color.hex', '#0f0'
    model.get('green').should.eql hex: '#0f0'
    
    model.del 'color.hex'
    model.get('green').should.eql {}
    
    model.del 'green'
    model.push 'color', 'item'
    model.get('green').should.eql ['item']
  
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
  
  'model events should get emitted properly': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn[0] = ++ver
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
  , 2
  
  'model events should be emitted on a reference': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn[0] = ++ver
      sockets.emit 'txn', txn, ver
    model.on 'set', 'color.*', (prop, value) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      sockets._disconnect()
      done()
    model.set 'color', model.ref 'colors.green'
    model.set 'color.hex', '#0f0'
  , 2
  
  'model events should be emitted on a reference to a reference': wrapTest (done) ->
    model = new Model
    model.set 'color', model.ref 'colors.green'
    model.set 'colors.green', model.ref 'bestColor'
    model.on 'set', 'color.hex', (value) ->
      value.should.eql '#0f0'
      done()
    model.on 'set', 'colors.**', (path, value) ->
      path.should.eql 'green.hex'
      value.should.eql '#0f0'
      done()
    model.set 'bestColor.hex', '#0f0'
  , 2

  'model events should not be emitted infinitely in the case of circular references': wrapTest (done) ->
    model = new Model
    # refs for test ops 1
    model.set 'users.1.bestFriend', model.ref 'users.2'
    model.set 'users.2.bestFriend', model.ref 'users.1'

    # refs for test ops 2
    model.set 'users.3.bestFriend', model.ref 'users.4'
    model.set 'users.4.bestFriend', model.ref 'users.5'
    model.set 'users.5.bestFriend', model.ref 'users.3'

    # refs for test ops 3
    model.set 'users.6.favOne', model.ref 'users.7'
    model.set 'users.7.favTwo', model.ref 'users.8'
    model.set 'users.8.favOne', model.ref 'users.6'

    counter = 0
    model.on 'set', 'users.**', (path, value) ->
      counter++
      switch counter
        # callbacks for tests ops 1
        when 1
          path.should.equal '2.age'
        when 2
          path.should.equal '1.bestFriend.age'
          # End of test ops 1
          , 500

        # callbacks for test ops 2
        when 3
          path.should.equal '5.age'
        when 4
          path.should.equal '4.bestFriend.age'
        when 5
          path.should.equal '3.bestFriend.bestFriend.age'
          
        # callbacks for test ops 3
        when 6
          path.should.equal '7.age'
        when 7
          path.should.equal '6.favOne.age'
        when 8
          path.should.equal '8.favOne.favOne.age'
          setTimeout ->
            counter.should.equal 8
            # End of test ops 2
            done()
          , 500
        # Re-tracing reference definitions beyond when 8
        # would result in redundant scenario of emitting on
        # 'users.7.favTwo.favOne.favOne.age', with callback
        # path parameter of '7.favTwo.favOne.favOne.age'
        # but this is just equal to '7.age', so our test
        # detects the right behavior here, which is to emit
        # all re-traced reference pointers up until this
        # redundant scenario
    # test ops 1
    model.set 'users.1.bestFriend.age', '50'

    # tests ops 2
    model.set 'users.4.bestFriend.age', '25'

    # test ops 3
    model.set 'users.6.favOne.age', '25'
  , 1
  
  'removing a reference should stop emission of events': wrapTest (done) ->
    model = new Model
    model.set 'color', model.ref 'colors.green'
    model.set 'colors.green', model.ref 'bestColor'
    model.on 'set', 'color.hex', done
    model.on 'set', 'colors.**', done
    model.del 'colors.green'
    model.set 'bestColor.hex', '#0f0'
  , 0
  
  'multiple references to the same path should all raise events': wrapTest (done) ->
    model = new Model
    model.set 'color', model.ref 'colors.green'
    model.set 'bestColor', model.ref 'colors.green'
    model.on 'set', 'color', done
    model.on 'set', 'bestColor', done
    model.set 'colors.green', {}
  , 2
  
  'references should work on different parts of a nested path': wrapTest (done) ->
    model = new Model
    model.set 'a', model.ref 'w.x.y.z'
    model.set 'b', model.ref 'w.x'
    model.on 'set', 'a', (value) ->
      value.should.eql 'green'
      done()
    model.on 'set', 'b.**', (path, value) ->
      path.should.eql 'y.z'
      value.should.eql 'green'
      done()
    model.set 'w.x.y.z', 'green'
  , 2
  
  'forcing a model method should create a transaction with a null version': ->
    model = new Model '0'
    model.set 'color', 'green'
    model.force.set 'color', 'red'
    model.force.del 'color'
    model._txns['0.0'].slice().should.eql [0, '0.0', 'set', 'color', 'green']
    model._txns['0.1'].slice().should.eql [null, '0.1', 'set', 'color', 'red']
    model._txns['0.2'].slice().should.eql [null, '0.2', 'del', 'color']
  
  'model mutator methods should callback on completion': wrapTest (done) ->
    ver = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn[0] = ++ver
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
    final.should.eql ['green']

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
    interim.should.eql ['green']
    model.pop 'colors'
    final = model.get 'colors'
    final.should.eql []

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
    interim.should.eql ['green']
    model.unshift 'colors', 'red', 'orange'
    final = model.get 'colors'
    final.should.eql ['red', 'orange', 'green']

  # TODO Test return value of unshift

  'model shift should remove the first member from an array': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.unshift 'colors', 'green', 'blue'
    interim = model.get 'colors'
    interim.should.eql ['green', 'blue']
    model.shift 'colors'
    final = model.get 'colors'
    final.should.eql ['blue']

  'model insertAfter should work on an array, with a valid index': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'green'
    interim = model.get 'colors'
    interim.should.eql ['green']
    model.insertAfter 'colors', 0, 'red'
    final = model.get 'colors'
    final.should.eql ['green', 'red']

  # TODO Test return value of insertAfter

  'model insertBefore should work on an array, with a valid index': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'green'
    interim = model.get 'colors'
    interim.should.eql ['green']
    model.insertBefore 'colors', 0, 'red'
    final = model.get 'colors'
    final.should.eql ['red', 'green']

  # TODO Test return value of insertBefore

  'model remove should work on an array, with a valid index': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'red', 'orange', 'yellow', 'green', 'blue', 'violet'
    interim = model.get 'colors'
    interim.should.eql ['red', 'orange', 'yellow', 'green', 'blue', 'violet']
    model.remove 'colors', 1, 4
    final = model.get 'colors'
    final.should.eql ['red', 'violet']

  # TODO Test return value of remove

  'model splice should work on an array, just like JS Array::splice': ->
    model = new Model '0'
    init = model.get 'colors'
    should.equal undefined, init
    model.push 'colors', 'red', 'orange', 'yellow', 'green', 'blue', 'violet'
    interim = model.get 'colors'
    interim.should.eql ['red', 'orange', 'yellow', 'green', 'blue', 'violet']
    model.splice 'colors', 1, 4, 'oak'
    final = model.get 'colors'
    final.should.eql ['red', 'oak', 'violet']

  # TODO Test return value of splice

  'test getting array of references': ->
    model = new Model
    model._adapter._data =
      todos:
        1: { text: 'finish rally', status: 'ongoing' }
        2: { text: 'run several miles', status: 'complete' }
        3: { text: 'meet with obama', status: 'complete' }
      _mine: ['1', '3']
      mine: model.ref 'todos', '_mine'
      mineTexts: model.ref 'todos', '_mine', 'text'

    # Test non-keyed array of references
    model.get('mine').should.eql [
        { text: 'finish rally', status: 'ongoing' }
      , { text: 'meet with obama', status: 'complete' }
    ]

    # Test access to single reference in the array
    model.get('mine.0').should.eql { text: 'finish rally', status: 'ongoing' }

    # Test access to a property below a single reference in the array
    model.get('mine.0.text').should.equal 'finish rally'

    # Test scoped array of references
    model.get('mineTexts').should.eql ['finish rally', 'meet with obama']

    # Test changing the key object reference with speculative set
    model.set '_mine', ['1', '2']
    model.get('mine').should.eql [
        { text: 'finish rally', status: 'ongoing' }
      , { text: 'run several miles', status: 'complete' }
    ]

    # Test changing referenced objects with speculative set
    model.set 'todos',
        1: { text: 'costco run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
    model.get('mine').should.eql [
        { text: 'costco run', status: 'complete' }
      , { text: 'party hard', status: 'ongoing' }
    ]

  'test setting to array of references': ->
    model = new Model

    # Setting a reference before a key should make a record of the key but
    # not the reference
    model.set 'mine', model.ref('todos', '_mine')
    model.get().should.protoEql
      mine: model.ref('todos', '_mine')
      $keys: { _mine: $: mine: ['todos', '_mine'] }

    # Setting a key value should update the reference
    model.set '_mine', ['1', '3']
    model.get().should.protoEql
      mine: model.ref 'todos', '_mine'
      _mine: ['1', '3']
      $keys: { _mine: $: mine: ['todos', '_mine'] }
      $refs:
        todos:
          1: { $: mine: ['todos', '_mine'] }
          3: { $: mine: ['todos', '_mine'] }
  
  'setting a property on an array reference member should update the referenced member': ->
    model = new Model
    model.set 'mine', model.ref('todos', '_mine')
    model.set '_mine', ['1', '3']
    model.set 'todos',
        1: { text: 'costco run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
    model.set 'mine.0.text', 'trader joes run'
    model.get('todos.1.text').should.equal 'trader joes run'
    model.get().should.protoEql
      todos:
        1: { text: 'trader joes run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
      mine: model.ref 'todos', '_mine'
      _mine: ['1', '3']
      $keys: { _mine: $: mine: ['todos', '_mine'] }
      $refs:
        todos:
          1: { $: mine: ['todos', '_mine'] }
          3: { $: mine: ['todos', '_mine'] }

  '''setting on a path that is currently a ref should modify the ref,
  similar to setting an object reference in Javascript''': ->
    model = new Model
    model.set 'mine', model.ref('todos', '_mine')
    model.set '_mine', ['1', '3']
    model.set 'todos',
        1: { text: 'costco run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
    model.set 'mine.0.text', 'trader joes run'

    model.set 'mine', model.ref 'dogs', '_mine'
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
      todos:
        1: { text: 'trader joes run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
      mine: model.ref 'dogs', '_mine'
      _mine: ['1', '3']
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] }
          3: { $: mine: ['dogs', '_mine'] }
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'pushing onto an array reference should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }

    model.set 'dogs.4', name: 'boo boo'
    model.push 'mine', model.ref('dogs', '4')
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'} # new data
      mine: model.ref 'dogs', '_mine'
      _mine: ['1', '3', '4'] # new data '4'
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] }
          3: { $: mine: ['dogs', '_mine'] }
          4: { $: mine: ['dogs', '_mine'] } # new data
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'banana' }
      { name: 'pogo' }
      { name: 'boo boo'}
    ]

  'popping an array reference should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['1', '3', '4']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.pop 'mine'
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.ref 'dogs', '_mine'
      _mine: ['1', '3'] # new data '4' popped()
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] }
          3: { $: mine: ['dogs', '_mine'] }
          # '4' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'unshifting an array reference should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.unshift 'mine', model.ref 'dogs', '4'
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.ref 'dogs', '_mine'
      _mine: ['4', '1', '3'] # new data '4'
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] }
          3: { $: mine: ['dogs', '_mine'] }
          4: { $: mine: ['dogs', '_mine'] } # new data
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'boo boo'}
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'shifting an array reference should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['4', '1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.shift 'mine'
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.ref 'dogs', '_mine'
      _mine: ['1', '3'] # new data '4' shifted()
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] }
          3: { $: mine: ['dogs', '_mine'] }
          # '4' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'insertAfter for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.insertAfter 'mine', 0, model.ref 'dogs', '4'
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'} # new data
      mine: model.ref 'dogs', '_mine'
      _mine: ['1', '4', '3'] # new data '4' inserted()
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] }
          3: { $: mine: ['dogs', '_mine'] }
          4: { $: mine: ['dogs', '_mine'] }
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'banana' }
      { name: 'boo boo'}
      { name: 'pogo' }
    ]

  'remove for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['1', '4', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.remove 'mine', 1
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.ref 'dogs', '_mine'
      _mine: ['1', '3'] # '4' removed()
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] }
          3: { $: mine: ['dogs', '_mine'] }
          # '4' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'insertBefore for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.insertBefore 'mine', 1, model.ref('dogs', '4')
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.ref 'dogs', '_mine'
      _mine: ['1', '4', '3'] # new data '4' inserted()
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] }
          3: { $: mine: ['dogs', '_mine'] }
          4: { $: mine: ['dogs', '_mine'] } # new data
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'banana' }
      { name: 'boo boo'}
      { name: 'pogo' }
    ]

  'removing multiple items at once for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['1', '4', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.remove 'mine', 0, 2
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.ref 'dogs', '_mine'
      _mine: ['3'] # '1' and '4' removed()
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          3: { $: mine: ['dogs', '_mine'] }
          # '1' removed
          # '4' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'pogo' }
    ]

  'splice for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.ref 'dogs', '_mine'
    model.set '_mine', ['1']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.splice 'mine', 0, 1, model.ref('dogs', '4'), model.ref('dogs', '1')
    model.get().should.protoEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'} # new data
      mine: model.ref 'dogs', '_mine'
      _mine: ['4', '1'] # new data '4', '1' spliced in; '3' spliced out
      $keys: { _mine: $: mine: ['dogs', '_mine'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine'] } # new data
          4: { $: mine: ['dogs', '_mine'] } # new data
          # '3' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'boo boo'}
      { name: 'banana' }
    ]

  "deleting a path that is pointed to by an array ref's key list should remove the reference to it from the key list": ->
    model = new Model
    model.set 'mine', model.ref 'todos', 'myTodoIds'
    model.set 'todos',
      1: { text: 'fight!' }
      2: { text: 'round two' }
      3: { text: 'finish him!' }
    model.set 'myTodoIds', ['1', '3']
    model.get('mine').should.eql [
      { text: 'fight!' }
      { text: 'finish him!' }
    ]
    model.get().should.protoEql
      todos:
        1: { text: 'fight!' }
        2: { text: 'round two' }
        3: { text: 'finish him!' }
      mine: model.ref 'todos', 'myTodoIds'
      myTodoIds: ['1', '3']
      $keys: { myTodoIds: $: mine: ['todos', 'myTodoIds'] }
      $refs:
        todos:
          1: { $: mine: ['todos', 'myTodoIds'] }
          3: { $: mine: ['todos', 'myTodoIds'] }
    model.del 'todos.3'
    model.get('mine').should.eql [
      { text: 'fight!' }
    ]
    model.get().should.protoEql
      todos:
        1: { text: 'fight!' }
        2: { text: 'round two' }
        # '3' removed
      mine: model.ref 'todos', 'myTodoIds'
      myTodoIds: ['1'] # '3' removed
      $keys: { myTodoIds: $: mine: ['todos', 'myTodoIds'] }
      $refs:
        todos:
          1: { $: mine: ['todos', 'myTodoIds'] }
          # '3' removed
    # TODO removal of the pending del transaction should also remove the other ref cleanup transactions it generates
