Model = require 'Model'
should = require 'should'
util = require './util'
transaction = require 'transaction'
wrapTest = util.wrapTest

mockSocketModel = require('./util/model').mockSocketModel

module.exports =
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
    model.get('numbers').should.specEql first: 2, second: 10
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
    model.get().should.specEql
      color: model.ref 'colors', 'selected'
      $keys: {selected: $: 'color': ['colors', 'selected'] }
    
    # Setting a key value should update the reference
    model.set 'selected', 'blue'
    model.get().should.specEql
      color: model.ref 'colors', 'selected'
      selected: 'blue'
      $keys: {selected: $: 'color': ['colors', 'selected'] }
      $refs: {colors: blue: $: 'color': ['colors', 'selected'] }
    
    # Setting a property on a reference should update the referenced object
    model.set 'color.hex', '#0f0'
    model.get().should.specEql
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
    model.get().should.specEql
      colors:
        blue:
          hex: '#0f0'
      color: model.ref 'colors.blue'
      selected: 'blue'
      $keys: {}
      $refs: {colors: blue: $: color: ['colors.blue', undefined] }

    # Test setting on a non-keyed reference
    model.set 'color.compliment', 'yellow'
    model.get().should.specEql
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
    model.get('green').should.specEql hex: '#0f0'
    
    model.del 'color.hex'
    model.get('green').should.specEql {}
    
    model.del 'green'
    should.equal undefined, model.get 'green'
    model.push 'color', 'item'
    model.get('green').should.specEql ['item']
  
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
  , 1
  
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

  'model events should be emitted on a private path reference (client-side)': wrapTest (done) ->
    serverModel = new Model
    serverModel.set '_room', serverModel.ref 'rooms.lobby'
    model = new Model
    model._adapter._data = JSON.parse JSON.stringify serverModel.get()
    model.on 'set', '_room.letters.*.position', (id, value) ->
      id.should.equal 'A'
      value.should.equal 5
      done()
    model.set '_room.players', 1
    model.set '_room.letters.A.position', 5
  , 1

# TODO Get this passing again
#  'model events should not be emitted infinitely in the case of circular references': wrapTest (done) ->
#    model = new Model
#    # refs for test ops 1
#    model.set 'users.1.bestFriend', model.ref 'users.2'
#    model.set 'users.2.bestFriend', model.ref 'users.1'
#
#    # refs for test ops 2
#    model.set 'users.3.bestFriend', model.ref 'users.4'
#    model.set 'users.4.bestFriend', model.ref 'users.5'
#    model.set 'users.5.bestFriend', model.ref 'users.3'
#
#    # refs for test ops 3
#    model.set 'users.6.favOne', model.ref 'users.7'
#    model.set 'users.7.favTwo', model.ref 'users.8'
#    model.set 'users.8.favOne', model.ref 'users.6'
#
#    counter = 0
#    model.on 'set', 'users.**', (path, value) ->
#      counter++
#      switch counter
#        # callbacks for tests ops 1
#        when 1
#          path.should.equal '2.age'
#        when 2
#          path.should.equal '1.bestFriend.age'
#          # End of test ops 1
#          , 500
#
#        # callbacks for test ops 2
#        when 3
#          path.should.equal '5.age'
#        when 4
#          path.should.equal '4.bestFriend.age'
#        when 5
#          path.should.equal '3.bestFriend.bestFriend.age'
#          
#        # callbacks for test ops 3
#        when 6
#          path.should.equal '7.age'
#        when 7
#          path.should.equal '6.favOne.age'
#        when 8
#          path.should.equal '8.favOne.favOne.age'
#          setTimeout ->
#            counter.should.equal 8
#            # End of test ops 2
#            done()
#          , 500
#        # Re-tracing reference definitions beyond when 8
#        # would result in redundant scenario of emitting on
#        # 'users.7.favTwo.favOne.favOne.age', with callback
#        # path parameter of '7.favTwo.favOne.favOne.age'
#        # but this is just equal to '7.age', so our test
#        # detects the right behavior here, which is to emit
#        # all re-traced reference pointers up until this
#        # redundant scenario
#    # test ops 1
#    model.set 'users.1.bestFriend.age', '50'
#
#    # tests ops 2
#    model.set 'users.4.bestFriend.age', '25'
#
#    # test ops 3
#    model.set 'users.6.favOne.age', '25'
#  , 1
  
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

  'test getting array of references': ->
    model = new Model
    model._adapter._data =
      todos:
        1: { text: 'finish rally', status: 'ongoing' }
        2: { text: 'run several miles', status: 'complete' }
        3: { text: 'meet with obama', status: 'complete' }
      _mine: ['1', '3']
      mine: model.arrayRef 'todos', '_mine'

    # Test non-keyed array of references
    model.get('mine').should.eql [
        { text: 'finish rally', status: 'ongoing' }
      , { text: 'meet with obama', status: 'complete' }
    ]

    # Test access to single reference in the array
    model.get('mine.0').should.eql { text: 'finish rally', status: 'ongoing' }

    # Test access to a property below a single reference in the array
    model.get('mine.0.text').should.equal 'finish rally'

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
    model.set 'mine', model.arrayRef('todos', '_mine')
    model.get().should.specEql
      mine: model.arrayRef('todos', '_mine')
      _mine: []
      $keys: { _mine: $: mine: ['todos', '_mine', 'array'] }

    # Setting a key value should update the reference
    model.set '_mine', ['1', '3']
    model.get().should.specEql
      mine: model.arrayRef 'todos', '_mine'
      _mine: ['1', '3']
      $keys: { _mine: $: mine: ['todos', '_mine', 'array'] }
      $refs:
        todos:
          1: { $: mine: ['todos', '_mine', 'array'] }
          3: { $: mine: ['todos', '_mine', 'array'] }

#  'pointer paths that include another pointer as a substring, should be stored for lookup by their fully de-referenced paths': ->
#    model = new Model
#    model.set '_group', model.ref 'groups.rally'
#    model.set '_group.todoList', model.arrayRef('_group.todos', '_group.todoIds')
#    model.get().should.specEql
#      _group: model.ref 'groups.rally'
#      groups:
#        rally:
#          todoIds: []
#          todoList: model.arrayRef('_group.todos', '_group.todoIds')
#      $keys:
#        _group:
#          todoIds:
#            $:
#              'groups.rally.todoList': ['_group.todos', '_group.todoIds', 'array']
#      $refs:
#        groups:
#          rally:
#            $:
#              _group: ['groups.rally', undefined]
#  # TODO Add test that is an extension to above test, where we change what '_group' points to. In this case, the other
#  #      pointers that include it as a substring should be updated

  'setting <arr-ref-pointer> = <ref-pointer>.<suffix>, when the array ref key already exists, should update the $refs index': ->
    model = new Model
    model.set '_group', model.ref 'groups.rally'
    model.set '_group.todoIds', ['1']
    model.set '_group.todoList', model.arrayRef('_group.todos', '_group.todoIds')
    model.get('$refs').should.specEql
      groups:
        rally:
          $: _group: ['groups.rally', undefined]
      _group:
        todos:
          1: { $: '_group.todoList': ['_group.todos', '_group.todoIds', 'array'] }

  'setting a key value for an <arr-ref-pointer> where <arr-ref-pointer> = <ref-pointer>.<suffix>, should update the $refs index': ->
    model = new Model
    model.set '_group', model.ref 'groups.rally'
    model.set '_group.todoList', model.arrayRef('_group.todos', '_group.todoIds')
    model.set '_group.todoIds', ['1']
    model.get('$refs').should.specEql
      groups:
        rally:
          $: _group: ['groups.rally', undefined]
      _group:
        todos:
          1: { $: '_group.todoList': ['_group.todos', '_group.todoIds', 'array'] }
  
  'setting a property on an array reference member should update the referenced member': ->
    model = new Model
    model.set 'mine', model.arrayRef('todos', '_mine')
    model.set '_mine', ['1', '3']
    model.set 'todos',
        1: { text: 'costco run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
    model.set 'mine.0.text', 'trader joes run'
    model.get('todos.1.text').should.equal 'trader joes run'
    model.get().should.specEql
      todos:
        1: { text: 'trader joes run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
      mine: model.arrayRef 'todos', '_mine'
      _mine: ['1', '3']
      $keys: { _mine: $: mine: ['todos', '_mine', 'array'] }
      $refs:
        todos:
          1: { $: mine: ['todos', '_mine', 'array'] }
          3: { $: mine: ['todos', '_mine', 'array'] }

  '''setting on a path that is currently a ref should modify the ref,
  similar to setting an object reference in Javascript''': ->
    model = new Model
    model.set 'mine', model.arrayRef('todos', '_mine')
    model.set '_mine', ['1', '3']
    model.set 'todos',
        1: { text: 'costco run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
    model.set 'mine.0.text', 'trader joes run'

    model.set 'mine', model.arrayRef 'dogs', '_mine'
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
      todos:
        1: { text: 'trader joes run', status: 'complete' }
        2: { text: 'party hard', status: 'ongoing' }
        3: { text: 'bounce', status: 'ongoing' }
      mine: model.arrayRef 'dogs', '_mine'
      _mine: ['1', '3']
      $keys: { _mine: $: mine: ['dogs', '_mine', 'array'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', '_mine', 'array'] }
          3: { $: mine: ['dogs', '_mine', 'array'] }
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.eql [
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'pushing onto an array reference should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', ['1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }

    model.set 'dogs.4', name: 'boo boo'
    model.push 'mine', model.arrayRef('dogs', '4')
    model.get().should.specEql
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['1', '3', '4'] # new data '4'
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] }
          3: { $: mine: ['dogs', 'myDogIds', 'array'] }
          4: { $: mine: ['dogs', 'myDogIds', 'array'] } # new data
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'} # new data
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'banana' }
      { name: 'pogo' }
      { name: 'boo boo'}
    ]

  'pushing onto an empty array reference should instantiate and update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'dogs', 1: name: 'banana'

    model.push 'mine', model.ref('dogs', '1')
    model.get().should.specEql
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      myDogIds: ['1'] # new array
      mine: model.arrayRef 'dogs', 'myDogIds'
      dogs:
        1: { name: 'banana' } # new data
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] } # new data
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [ name: 'banana' ]

  '''pushing an object  -- that is not a reference but that has an id attribute
  -- onto a path pointing to an array ref should add the object to the array refs
  $r namespace and push the id onto the $k path''': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.push 'mine', id: 1, name: 'banana'

    model.get().should.specEql
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['1']
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] }
      dogs:
        1: { id: 1, name: 'banana' }
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { id: 1, name: 'banana' }
    ]

  '''pushing an non-ref object onto a path pointing to an array ref
  should place the transaction setting the new object before the
  transaction pushing the ref of that object''': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.push 'mine', id: 1, name: 'banana'
    model._txnQueue.map((id) ->
      txn = model._txns[id]
      delete txn.callback
      txn
    ).should.eql [
        [ 0, '.0', 'set', 'mine', { '$r': 'dogs', '$k': 'myDogIds', '$t': 'array' } ]
      , [ 0, '.1', 'set', 'dogs.1', { id: 1, name: 'banana' } ]
      , [ 0, '.2', 'push', 'myDogIds', '1'],
    ]

  'popping an array reference should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', ['1', '3', '4']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.pop 'mine'
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['1', '3'] # new data '4' popped()
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] }
          3: { $: mine: ['dogs', 'myDogIds', 'array'] }
          # '4' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'unshifting an array reference should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', ['1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.unshift 'mine', model.arrayRef 'dogs', '4'
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['4', '1', '3'] # new data '4'
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] }
          3: { $: mine: ['dogs', 'myDogIds', 'array'] }
          4: { $: mine: ['dogs', 'myDogIds', 'array'] } # new data
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'boo boo'}
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'shifting an array reference should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', ['4', '1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.shift 'mine'
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['1', '3'] # new data '4' shifted()
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] }
          3: { $: mine: ['dogs', 'myDogIds', 'array'] }
          # '4' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'insertAfter for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myTodoIds'
    model.set 'myTodoIds', ['1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.insertAfter 'mine', 0, model.arrayRef 'dogs', '4'
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'} # new data
      mine: model.arrayRef 'dogs', 'myTodoIds'
      myTodoIds: ['1', '4', '3'] # new data '4' inserted()
      $keys: { myTodoIds: $: mine: ['dogs', 'myTodoIds', 'array'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myTodoIds', 'array'] }
          3: { $: mine: ['dogs', 'myTodoIds', 'array'] }
          4: { $: mine: ['dogs', 'myTodoIds', 'array'] }
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'banana' }
      { name: 'boo boo'}
      { name: 'pogo' }
    ]

  'remove for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', ['1', '4', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.remove 'mine', 1
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['1', '3'] # '4' removed()
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] }
          3: { $: mine: ['dogs', 'myDogIds', 'array'] }
          # '4' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'banana' }
      { name: 'pogo' }
    ]

  'insertBefore for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', ['1', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.insertBefore 'mine', 1, model.ref('dogs', '4')
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['1', '4', '3'] # new data '4' inserted()
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] }
          3: { $: mine: ['dogs', 'myDogIds', 'array'] }
          4: { $: mine: ['dogs', 'myDogIds', 'array'] } # new data
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'banana' }
      { name: 'boo boo'}
      { name: 'pogo' }
    ]

  'removing multiple items at once for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', ['1', '4', '3']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.remove 'mine', 0, 2
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'}
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['3'] # '1' and '4' removed()
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      $refs:
        dogs:
          3: { $: mine: ['dogs', 'myDogIds', 'array'] }
          # '1' removed
          # '4' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'pogo' }
    ]

  'splice for array references should update the key array': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', ['1']
    model.set 'dogs',
      1: { name: 'banana' }
      2: { name: 'squeak' }
      3: { name: 'pogo' }
      4: { name: 'boo boo'}

    model.splice 'mine', 0, 1, model.ref('dogs', '4'), model.ref('dogs', '1')
    model.get().should.specEql
      dogs:
        1: { name: 'banana' }
        2: { name: 'squeak' }
        3: { name: 'pogo' }
        4: { name: 'boo boo'} # new data
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: ['4', '1'] # new data '4', '1' spliced in; '3' spliced out
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] } # new data
          4: { $: mine: ['dogs', 'myDogIds', 'array'] } # new data
          # '3' removed
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [
      { name: 'boo boo'}
      { name: 'banana' }
    ]

  "deleting a path that is pointed to by an array ref's key list should remove the reference to it from the key list": ->
    model = new Model
    model.set 'mine', model.arrayRef 'todos', 'myTodoIds'
    model.set 'todos',
      1: { text: 'fight!' }
      2: { text: 'round two' }
      3: { text: 'finish him!' }
    model.set 'myTodoIds', ['1', '3']
    model.get('mine').should.specEql [
      { text: 'fight!' }
      { text: 'finish him!' }
    ]
    model.get().should.specEql
      todos:
        1: { text: 'fight!' }
        2: { text: 'round two' }
        3: { text: 'finish him!' }
      mine: model.arrayRef 'todos', 'myTodoIds'
      myTodoIds: ['1', '3']
      $keys: { myTodoIds: $: mine: ['todos', 'myTodoIds', 'array'] }
      $refs:
        todos:
          1: { $: mine: ['todos', 'myTodoIds', 'array'] }
          3: { $: mine: ['todos', 'myTodoIds', 'array'] }
    model.del 'todos.3'
    model.get('mine').should.specEql [
      { text: 'fight!' }
    ]
    model.get().should.specEql
      todos:
        1: { text: 'fight!' }
        2: { text: 'round two' }
        # '3' removed
      mine: model.arrayRef 'todos', 'myTodoIds'
      myTodoIds: ['1'] # '3' removed
      $keys: { myTodoIds: $: mine: ['todos', 'myTodoIds', 'array'] }
      $refs:
        todos:
          1: { $: mine: ['todos', 'myTodoIds', 'array'] }
          # '3' removed
    # TODO removal of the pending del transaction should also remove the other ref cleanup transactions it generates

  'setting on a property involving both a ref and an array ref key path should emit model events on to a path with the ref path and array ref path substituted in for the ref and key path respectively': wrapTest (done) ->
    model = new Model
    model.set '_group', model.ref 'groups.rally'
    model.set '_group.todoList', model.arrayRef('_group.todos', '_group.todoIds')
    model.set '_group.todoIds', ['1']
    model.set '_group.todos',
      1: complete: false
    # TODO Test for proper path passed to callback for `on 'set', '_group.todoList.**'`
    model.on 'set', '_group.todoList.0.complete', (value) ->
      value.should.be.true
      done()
    model.set 'groups.rally.todos.1.complete', true
  , 1

  "pushing onto an array ref's key array should emit model events on the ref and on its pointers": wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
    model.on 'push', 'myTodos', (dereffedVal) ->
      # ref.should.eql model.ref('todos', '1')
      dereffedVal.should.eql { text: 'something' }
      done()
    model.on 'push', 'myTodoIds', (val) ->
      val.should.equal '1'
      done()
    model.push 'myTodoIds', '1'
  , 2

#  "pusing onto an array ref > once should result in the proper update to the array key": ->
#    [sockets, model] = mockSocketModel('clientA')
#    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
#    model.push 'myTodos', id: '1', text: 'one'
#    model.push 'myTodos', id: '2', text: 'two'
#    model.get('myTodoIds').should.eql ['1', '2']
#    sockets.emit 'txn', [1, 'clientA.1', 'push', 'myTodoIds', '2'], 1
#    model.get('myTodoIds').should.eql ['1', '2']
#    sockets._disconnect()

  'pushing onto an array ref pointer should emit model events on the pointer and on its ref': wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
    model.on 'push', 'myTodos', (dereffedVal) ->
      # ref.should.eql model.ref('todos', '1')
      dereffedVal.should.eql { text: 'something' }
      done()
    model.on 'push', 'myTodoIds', (val) ->
      val.should.equal '1'
      done()
    model.push 'myTodos', model.ref('todos', '1')
  , 2

  "popping an array ref's key array should emit model events on the ref and on its pointers": wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
    model.set 'myTodoIds', ['1']
    model.on 'pop', 'myTodos', ->
      done()
    model.on 'pop', 'myTodoIds', ->
      done()
    model.pop 'myTodoIds'
  , 2

  'popping an array ref pointer should emit model events on the pointer and on its ref': wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
    model.set 'myTodoIds', ['1']
    model.on 'pop', 'myTodos', ->
      done()
    model.on 'pop', 'myTodoIds', ->
      done()
    model.pop 'myTodos'
  , 2

  "insertAfter on an array ref's key array should emit model events on the ref and on its pointers": wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
    model.on 'insertAfter', 'myTodos', (index, dereffedVal) ->
      index.should.equal -1
      # ref.should.eql model.ref('todos', '1')
      dereffedVal.should.eql { text: 'something' }
      done()
    model.on 'insertAfter', 'myTodoIds', (index, val) ->
      index.should.equal -1
      val.should.equal '1'
      done()
    model.insertAfter 'myTodoIds', -1, '1'
  , 2

  'insertAfter on an array ref pointer should emit model events on the pointer and on its ref': wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
    model.on 'insertAfter', 'myTodos', (index, dereffedVal) ->
      index.should.equal -1
      # ref.should.eql model.ref('todos', '1')
      dereffedVal.should.eql { text: 'something' }
      done()
    model.on 'insertAfter', 'myTodoIds', (index, val) ->
      index.should.equal -1
      val.should.equal '1'
      done()
    model.insertAfter 'myTodos', -1, model.ref('todos', '1')
  , 2

  "insertBefore on an array ref's key array should emit model events on the ref and on its pointers": wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
    model.on 'insertBefore', 'myTodos', (index, dereffedVal) ->
      index.should.equal 0
      # ref.should.eql model.ref('todos', '1')
      dereffedVal.should.eql { text: 'something' }
      done()
    model.on 'insertBefore', 'myTodoIds', (index, val) ->
      index.should.equal 0
      val.should.equal '1'
      done()
    model.insertBefore 'myTodoIds', 0, '1'
  , 2

  'insertBefore on an array ref pointer should emit model events on the pointer and on its ref': wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
    model.on 'insertBefore', 'myTodos', (index, dereffedVal) ->
      index.should.equal 0
      # ref.should.eql model.ref('todos', '1')
      dereffedVal.should.eql { text: 'something' }
      done()
    model.on 'insertBefore', 'myTodoIds', (index, val) ->
      index.should.equal 0
      val.should.equal '1'
      done()
    model.insertBefore 'myTodos', 0, model.ref('todos', '1')
  , 2

  "remove on an array ref's key array should emit model events on the ref and on its pointers": wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
      2: { text: 'more' }
      3: { text: 'blah' }
    model.set 'myTodoIds', ['1', '2', '3']
    model.on 'remove', 'myTodos', (index, removeCount) ->
      index.should.equal 0
      removeCount.should.equal 2
      done()
    model.on 'remove', 'myTodoIds', (index, removeCount) ->
      index.should.equal 0
      removeCount.should.equal 2
      done()
    model.remove 'myTodoIds', 0, 2
  , 2

  'remove on an array ref pointer should emit model events on the pointer and on its ref': wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
      2: { text: 'more' }
      3: { text: 'blah' }
    model.set 'myTodoIds', ['1', '2', '3']
    model.on 'remove', 'myTodos', (index, removeCount) ->
      index.should.equal 0
      removeCount.should.equal 2
      done()
    model.on 'remove', 'myTodoIds', (index, removeCount) ->
      index.should.equal 0
      removeCount.should.equal 2
      done()
    model.remove 'myTodos', 0, 2
  , 2

  "splice on an array ref's key array should emit model events on the ref and on its pointers": wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
      2: { text: 'more' }
      3: { text: 'blah' }
    model.set 'myTodoIds', ['1', '2']
    model.on 'splice', 'myTodos', (index, removeCount, dereffedVal) ->
      index.should.equal 0
      removeCount.should.equal 1
      # ref.should.eql model.ref('todos', '3')
      dereffedVal.should.eql { text: 'blah' }
      done()
    model.on 'splice', 'myTodoIds', (index, removeCount, value) ->
      index.should.equal 0
      removeCount.should.equal 1
      value.should.equal '3'
      done()
    model.splice 'myTodoIds', 0, 1, '3'
  , 2

  'splice on an array ref pointer should emit model events on the pointer and on its ref': wrapTest (done) ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      1: { text: 'something' }
      2: { text: 'more' }
      3: { text: 'blah' }
    model.set 'myTodoIds', ['1', '2']
    model.on 'splice', 'myTodos', (index, removeCount, dereffedVal) ->
      index.should.equal 0
      removeCount.should.equal 1
      # ref.should.eql model.ref('todos', '3')
      dereffedVal.should.eql { text: 'blah' }
      done()
    model.on 'splice', 'myTodoIds', (index, removeCount, value) ->
      index.should.equal 0
      removeCount.should.equal 1
      value.should.equal '3'
      done()
    model.splice 'myTodos', 0, 1, model.ref('todos', '3')
  , 2

  'pushing onto an array ref that involves a regular pointer as part of its path, should update the $refs index with the newest array member': ->
    model = new Model
    model.set '_group', model.ref 'groups.rally'
    model.set '_group.todoList', model.arrayRef('_group.todos', '_group.todoIds')
    model.push '_group.todoList',
      id: 5
      text: 'fix this'
      completed: false

    model.get().should.specEql
      _group: model.ref 'groups.rally'
      groups:
        rally:
          todos:
            5: { id: 5, text: 'fix this', completed: false }
          todoIds: ['5']
          todoList: model.arrayRef '_group.todos', '_group.todoIds'
      $keys:
        _group:
          todoIds:
            $: 'groups.rally.todoList': ['_group.todos', '_group.todoIds', 'array']
      $refs:
        groups:
          rally:
            $: _group: ['groups.rally', undefined]
        # The following should be present
        _group:
          todos:
            5:
              $: 'groups.rally.todoList': ['_group.todos', '_group.todoIds', 'array']


  ## id api for array mutators ##

  'remove an array ref member by id should remove the id from the array ref key array': ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      10: { id: '10', text: 'something' }
      20: { id: '20', text: 'more' }
    model.set 'myTodoIds', ['10', '20']
    model.remove 'myTodos', id: '20'
    model.get('myTodoIds').should.specEql ['10']

  'insertAfter an array ref member by id should insert the member after the id in the ref key array': ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      10: { id: '10', text: 'something' }
      20: { id: '20', text: 'more' }
    model.set 'myTodoIds', ['10', '20']
    model.insertAfter 'myTodos', {id: '10'},
      id: '30'
      text: 'blah'
    model.get('myTodoIds').should.specEql ['10', '30', '20']

  'insertBefore an array ref member by id should insert the member before the id in the ref key array': ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      10: { id: '10', text: 'something' }
      20: { id: '20', text: 'more' }
    model.set 'myTodoIds', ['10', '20']
    model.insertBefore 'myTodos', {id: '10'},
      id: '30'
      text: 'blah'
    model.get('myTodoIds').should.specEql ['30', '10', '20']

  'splice of an array ref member by id should do the splice relative to the index of the id in the ref key array': ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      10: { id: '10', text: 'something' }
      20: { id: '20', text: 'more' }
    model.set 'myTodoIds', ['10', '20']
    model.splice 'myTodos', {id: '10'}, 1
      id: '30'
      text: 'blah'
    model.get('myTodoIds').should.specEql ['30', '20']
