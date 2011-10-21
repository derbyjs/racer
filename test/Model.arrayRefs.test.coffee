Model = require 'Model'
should = require 'should'
util = require './util'
transaction = require 'transaction'
wrapTest = util.wrapTest

{mockSocketModel, mockSocketModels} = require './util/model'

module.exports =
  'test getting array of references': ->
    model = new Model
    model._adapter._data =
      world:
        todos:
          1: { text: 'finish racer', status: 'ongoing' }
          2: { text: 'run several miles', status: 'complete' }
          3: { text: 'meet with obama', status: 'complete' }
        _mine: ['1', '3']
        mine: model.arrayRef 'todos', '_mine'

    # Test non-keyed array of references
    model.get('mine').should.eql [
        { text: 'finish racer', status: 'ongoing' }
      , { text: 'meet with obama', status: 'complete' }
    ]

    # Test access to single reference in the array
    model.get('mine.0').should.eql { text: 'finish racer', status: 'ongoing' }

    # Test access to a property below a single reference in the array
    model.get('mine.0.text').should.equal 'finish racer'

    # Test changing the key object reference with speculative set
    model.set '_mine', ['1', '2']
    model.get('mine').should.eql [
        { text: 'finish racer', status: 'ongoing' }
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
    model.set 'mine', model.arrayRef 'todos', '_mine'
    model.get().should.specEql
      mine: model.arrayRef 'todos', '_mine'
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
      todos: {}

  'pointer paths that include another pointer as a substring, should be stored for lookup by their fully de-referenced paths': ->
    model = new Model
    model.set '_group', model.ref 'groups.racer'
    model.set '_group.todoList', model.arrayRef '_group.todos', '_group.todoIds'
    model.get().should.specEql
      _group: model.ref 'groups.racer'
      groups:
        racer:
          todoIds: []
          todoList: model.arrayRef('_group.todos', '_group.todoIds')
      $keys:
        _group:
          todoIds:
            $:
              'groups.racer.todoList': ['_group.todos', '_group.todoIds', 'array']
      $refs:
        groups:
          racer:
            $:
              _group: ['groups.racer', undefined]
  # TODO Add test that is an extension to above test, where we change what '_group' points to. In this case, the other
  #      pointers that include it as a substring should be updated

  'setting <arr-ref-pointer> = <ref-pointer>.<suffix>, when the array ref key already exists, should update the $refs index': ->
    model = new Model
    model.set '_group', model.ref 'groups.racer'
    model.set '_group.todoIds', ['1']
    model.set '_group.todoList', model.arrayRef('_group.todos', '_group.todoIds')
    model.get('$refs').should.specEql
      groups:
        racer:
          $: _group: ['groups.racer', undefined]
      _group:
        todos:
          1: { $: 'groups.racer.todoList': ['_group.todos', '_group.todoIds', 'array'] }

  'setting a key value for an <arr-ref-pointer> where <arr-ref-pointer> = <ref-pointer>.<suffix>, should update the $refs index': ->
    model = new Model
    model.set '_group', model.ref 'groups.racer'
    model.set '_group.todoList', model.arrayRef('_group.todos', '_group.todoIds')
    model.set '_group.todoIds', ['1']
    model.get('$refs').should.specEql
      groups:
        racer:
          $: _group: ['groups.racer', undefined]
      _group:
        todos:
          1: { $: 'groups.racer.todoList': ['_group.todos', '_group.todoIds', 'array'] }
  
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

  'setting on a path that is currently an array ref should modify the
    array ref, similar to setting an object reference in Javascript': ->
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
      4: { name: 'boo boo' }

    model.push 'mine', id: '4'
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

    model.push 'mine', id: '1', name: 'banana'
    model.get().should.specEql
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      myDogIds: ['1'] # new array
      mine: model.arrayRef 'dogs', 'myDogIds'
      dogs:
        1: { id: '1', name: 'banana' } # new data
      $refs:
        dogs:
          1: { $: mine: ['dogs', 'myDogIds', 'array'] } # new data
    # ... and should result in a model that can dereference the
    # new references properly
    model.get('mine').should.specEql [ id: '1', name: 'banana' ]

  '''pushing an object  -- that is not a reference but that has an id attribute
  -- onto a path pointing to an array ref should add the object to the array refs
  $r namespace and push the id onto the $k path''': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.push 'mine', id: 1, name: 'banana'

    model.get().should.specEql
      $keys: { myDogIds: $: mine: ['dogs', 'myDogIds', 'array'] }
      mine: model.arrayRef 'dogs', 'myDogIds'
      myDogIds: [1]
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

  '''pushing a non-ref object onto a path pointing to an array ref
  should place the transaction setting the new object before the
  transaction pushing the ref of that object''': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.push 'mine', id: 1, name: 'banana'
    expected = [
        transaction.create(base: 0, id: '.0', method: 'set', args: ['mine', { '$r': 'dogs', '$k': 'myDogIds', '$t': 'array' } ])
      , transaction.create(base: 0, id: '.1', method: 'set', args: ['dogs.1', { id: 1, name: 'banana' } ])
      , transaction.create(base: 0, id: '.2', method: 'push', args: ['myDogIds', 1]),
    ]
    expected.forEach (txn) -> txn.emitted = true
    model._txnQueue.map((id) ->
      txn = model._txns[id]
      delete txn.callback
      txn
    ).should.eql expected

  '''pushing an non-ref object onto a path pointing to an
  empty array ref should not fail''': ->
    model = new Model
    model.set 'mine', model.arrayRef 'dogs', 'myDogIds'
    model.set 'myDogIds', []
    err = null
    try
      model.push 'mine', id: 1, name: 'banana'
    catch e
      err = e
    should.equal err, null

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
      4: { name: 'boo boo' }

    model.unshift 'mine', id: '4'
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

    model.insertAfter 'mine', 0, id: '4'
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

    model.insertBefore 'mine', 1, id: '4'
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

    model.splice 'mine', 0, 1, {id: '4'}, {id: '1'}
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
    model.set '_group', model.ref 'groups.racer'
    model.set '_group.todoList', model.arrayRef('_group.todos', '_group.todoIds')
    model.set '_group.todoIds', ['1']
    model.set '_group.todos',
      1: complete: false
    # TODO Test for proper path passed to callback for `on 'set', '_group.todoList'`
    model.on 'set', '_group.todoList.0.complete', (value) ->
      value.should.be.true
      done()
    model.set 'groups.racer.todos.1.complete', true
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
    model.push 'myTodos', id: '1'
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
    model.insertAfter 'myTodos', -1, id: '1'
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
    model.insertBefore 'myTodos', 0, id: '1'
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
    model.splice 'myTodos', 0, 1, id: '3'
  , 2

  'pushing onto an array ref that involves a regular pointer as part of its path, should update the $refs index with the newest array member': ->
    model = new Model
    model.set '_group', model.ref 'groups.racer'
    model.set '_group.todoList', model.arrayRef '_group.todos', '_group.todoIds'
    model.push '_group.todoList',
      id: 5
      text: 'fix this'
      completed: false

    model.get().should.specEql
      _group: model.ref 'groups.racer'
      groups:
        racer:
          todos:
            5: { id: 5, text: 'fix this', completed: false }
          todoIds: [5]
          todoList: model.arrayRef '_group.todos', '_group.todoIds'
      $keys:
        _group:
          todoIds:
            $: 'groups.racer.todoList': ['_group.todos', '_group.todoIds', 'array']
      $refs:
        groups:
          racer:
            $: _group: ['groups.racer', undefined]
        # The following should be present
        _group:
          todos:
            5:
              $: 'groups.racer.todoList': ['_group.todos', '_group.todoIds', 'array']


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

  'removing on an array ref by index api in one browser should pass index semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
      3: { id: 3, text: 'third', complete: false }
    modelA.set 'todoIds', [3,1,2]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'remove', 'todoList', (startIndex, howMany) ->
      startIndex.should.equal 1
      sockets._disconnect()
      done()
    modelA.remove 'todoList', 1
  , 1

  'removing on an array ref by id api in one browser should pass id semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
      3: { id: 3, text: 'third', complete: false }
    modelA.set 'todoIds', [3, 1, 2]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'remove', 'todoList', ({id}, howMany) ->
      id.should.equal 3
      howMany.should.equal 1
      sockets._disconnect()
      done()
    modelA.remove 'todoList', {id: 3}
  , 1

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

  'insertAfter on an array ref by index api in one browser should pass index semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
    modelA.set 'todoIds', [2,1]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'insertAfter', 'todoList', (afterIndex, todo) ->
      afterIndex.should.equal 1
      todo.should.specEql id: 3, text: 'third', complete: false
      sockets._disconnect()
      done()
    modelA.insertAfter 'todoList', 1, {id: 3, text: 'third', complete: false}
  , 1

  'insertAfter on an array ref by id api in one browser should pass id semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
    modelA.set 'todoIds', [2,1]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'insertAfter', 'todoList', ({id}, todo) ->
      id.should.equal 2
      todo.should.specEql id: 3, text: 'third', complete: false
      sockets._disconnect()
      done()
    modelA.insertAfter 'todoList', {id: 2}, {id: 3, text: 'third', complete: false}
  , 1

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

  'insertBefore on an array ref by index api in one browser should pass index semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
    modelA.set 'todoIds', [2,1]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'insertBefore', 'todoList', (beforeIndex, todo) ->
      beforeIndex.should.equal 1
      todo.should.specEql id: 3, text: 'third', complete: false
      sockets._disconnect()
      done()
    modelA.insertBefore 'todoList', 1, {id: 3, text: 'third', complete: false}
  , 1

  'insertBefore on an array ref by id api in one browser should pass id semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
    modelA.set 'todoIds', [2,1]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'insertBefore', 'todoList', ({id}, todo) ->
      id.should.equal 2
      todo.should.specEql id: 3, text: 'third', complete: false
      sockets._disconnect()
      done()
    modelA.insertBefore 'todoList', {id: 2}, {id: 3, text: 'third', complete: false}
  , 1

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

  'splice on an array ref by index api in one browser should pass index semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
    modelA.set 'todoIds', [2,1]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'splice', 'todoList', (index, howMany, todo) ->
      index.should.equal 0
      howMany.should.equal 1
      todo.should.specEql id: 3, text: 'third', complete: false
      sockets._disconnect()
      done()
    modelA.splice 'todoList', 0, 1, {id: 3, text: 'third', complete: false}
  , 1

  'splice on an array ref by id api in one browser should pass id semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
    modelA.set 'todoIds', [2,1]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'splice', 'todoList', ({id}, howMany, todo) ->
      id.should.equal 2
      howMany.should.equal 1
      todo.should.specEql id: 3, text: 'third', complete: false
      sockets._disconnect()
      done()
    modelA.splice 'todoList', {id: 2}, 1, {id: 3, text: 'third', complete: false}
  , 1

  'move of an array ref member by id should do the move relative to the index of the id in the ref key array': ->
    model = new Model
    model.set 'myTodos', model.arrayRef('todos', 'myTodoIds')
    model.set 'todos',
      10: { id: '10', text: 'something' }
      20: { id: '20', text: 'more' }
      30: { id: '30', text: 'doodle' }
    model.set 'myTodoIds', ['10', '20', '30']
    model.move 'myTodos', {id: '10'}, 2
    model.get('myTodoIds').should.specEql ['20', '30', '10']
    model.get('myTodos').should.specEql [
        { id: '20', text: 'more' }
      , { id: '30', text: 'doodle' }
      , { id: '10', text: 'something' }
    ]

  'move on an array ref by index api in one browser should pass index semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
    modelA.set 'todoIds', [2,1]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'move', 'todoList', (from, to) ->
      from.should.equal 0
      to.should.equal 1
      sockets._disconnect()
      done()
    modelA.move 'todoList', 0, 1
  , 1

  'move on an array ref by id api in one browser should pass id semantics to the callback in another browser': wrapTest (done) ->
    [sockets, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
    modelA.set 'todos',
      1: { id: 1, text: 'first', complete: false }
      2: { id: 2, text: 'second', complete: false }
    modelA.set 'todoIds', [2,1]
    modelA.set 'todoList', modelA.arrayRef 'todos', 'todoIds'
    modelB.on 'move', 'todoList', ({id}, to) ->
      id.should.equal 2
      to.should.equal 1
      sockets._disconnect()
      done()
    modelA.move 'todoList', {id: 2}, 1
  , 1
