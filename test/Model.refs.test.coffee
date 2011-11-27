Model = require '../src/Model'
should = require 'should'
util = require './util'
transaction = require '../src/transaction'
wrapTest = util.wrapTest

{mockSocketModel} = require './util/model'

module.exports =
  'test getting model references': ->
    model = new Model
    model._adapter._data =
      world:
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

  'test setting to model references in a nested way': ->
    model = new Model
    model.set 'users.1', 'brian'
    model.set 'session',
      user: model.ref 'users.1'
    model.get('session.user').should.equal 'brian'

  'test setting to model references with a key in a nested way': ->
    model = new Model
    model.set 'users.1', 'brian'
    model.set 'userId', '1'
    model.set 'session',
      user: model.ref 'users', 'userId'
    model.get('session.user').should.equal 'brian'

  'test setting to model references with a key in a self-referencing way': ->
    model = new Model
    model.set 'users.1', 'brian'
    model.set 'session',
      userId: 1
      user: model.ref 'users', 'session.userId'
    model.get('session.user').should.equal 'brian'

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
      txn.slice().should.eql expected[count++]
      sockets._disconnect()
      done()
    expected = [
      transaction.create(base: 0, id: '0.0', method: 'set', args: ['color', model.ref 'colors.green'])
      transaction.create(base: 0, id: '0.1', method: 'set', args: ['colors.green.hex', '#0f0'])
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
  
  'model events should be emitted upstream on a reference to a reference': wrapTest (done) ->
    model = new Model
    model.set 'color', model.ref 'colors.green'
    model.set 'colors.green', model.ref 'bestColor'
    model.on 'set', 'color.hex', (value) ->
      value.should.eql '#0f0'
      done()
    model.on 'set', 'colors.*', (path, value) ->
      path.should.eql 'green.hex'
      value.should.eql '#0f0'
      done()
    model.set 'bestColor.hex', '#0f0'
  , 2

  'model events should be emitted upstream on a reference to a reference (private version)': wrapTest (done) ->
    model = new Model
    model.set 'color', model.ref '_colors.green'
    model.set '_colors.green', model.ref '_bestColor'
    model.on 'set', 'color.hex', (value) ->
      value.should.eql '#0f0'
      done()
    model.on 'set', '_colors.*', (path, value) ->
      path.should.eql 'green.hex'
      value.should.eql '#0f0'
      done()
    model.set '_bestColor.hex', '#0f0'
  , 2

  'tmp': wrapTest (done) ->
    model = new Model
    model.set '_room', model.ref 'rooms.lobby'
    model.set '_user', model.ref '_room.users.0'
    model.on 'set', '_room.users.0.name', (value) ->
      value.should.eql '#0f0'
      done()
    model.on 'set', '_user.name', (value) ->
      value.should.eql '#0f0'
      done()
    model.on 'set', 'rooms.lobby.users.0.name', (value) ->
      value.should.eql '#0f0'
      done()
    model.set '_user.name', '#0f0'
  , 3

  'model events should be emitted on a private path reference (client-side)': wrapTest (done) ->
    serverModel = new Model
    serverModel.set '_room', serverModel.ref 'rooms.lobby'
    model = new Model
    model._adapter._data.world = JSON.parse JSON.stringify serverModel.get()
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
#    model.on 'set', 'users.*', (path, value) ->
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
    model.on 'set', 'colors.*', done
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
    model.on 'set', 'b.*', (path, value) ->
      path.should.eql 'y.z'
      value.should.eql 'green'
      done()
    model.set 'w.x.y.z', 'green'
  , 2

  'references set in a nested way should emit events': wrapTest (done) ->
    model = new Model
    model.set 'users.1', name: 'brian'
    model.set 'session',
      user: model.ref 'users.1'
    model.on 'set', 'session.user.name', done
    model.on 'set', 'users.1.name', done
    model.set 'session.user.name', 'nate'
  , 2

  'references with a key set in a nested way should emit events': wrapTest (done) ->
    model = new Model
    model.set 'users.1', name: 'brian'
    model.set 'userId', '1'
    model.set 'session',
      user: model.ref 'users', 'userId'
    model.on 'set', 'session.user.name', done
    model.on 'set', 'users.1.name', done
    model.set 'session.user.name', 'nate'
  , 2

  'references with a key set in a self-referencing way should emit events': wrapTest (done) ->
    model = new Model
    model.set '_room', model.ref 'rooms.1'
    model.set '_session',
      userId: 0
      user: model.ref '_room.users', '_session.userId'
    addListener = (path) ->
      model.on 'set', path, (value) ->
        value.should.eql 'Bob'
        done()
    addListener 'rooms.1.users.0.name'
    addListener '_room.users.0.name'
    addListener '_session.user.name'
    model.set '_session.user.name', 'Bob'
  , 3
