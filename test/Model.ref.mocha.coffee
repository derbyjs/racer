Model = require '../src/Model'
should = require 'should'
{calls} = require './util'

transaction = require '../src/transaction'
{mockSocketModel} = require './util/model'

describe 'Model.ref', ->

  it 'should support getting', ->
    model = new Model
    model.set 'info',
      numbers:
        first: 2
        second: 10
    model.set 'numKey', 'first'
    model.ref '_numbers', 'info.numbers'
    model.ref '_number', '_numbers', 'numKey'

    # Test non-keyed object reference
    model.get('_numbers').should.specEql first: 2, second: 10
    # Test property below object reference
    model.get('_numbers.second').should.eql 10
    # Test keyed object reference
    model.get('_number').should.eql 2

    # Test changing key object reference with speculative set
    model.set 'numKey', 'second'
    model.get('_number').should.eql 10
    # Test changing referenced object wtih speculative set
    model.set 'info', numbers: {first: 3, second: 7}
    model.get('_number').should.eql 7
  
  it 'should support setting', ->
    model = new Model
    
    ref = model.ref '_color', 'colors', 'selected'
    model.get().should.specEql
      _color: ref
    
    # Set a key value
    model.set 'selected', 'blue'
    model.get().should.specEql
      _color: ref
      selected: 'blue'

    # Setting a property on a reference should update the referenced object
    model.set '_color.hex', '#0f0'
    model.get().should.specEql
      colors:
        blue:
          hex: '#0f0'
      _color: ref
      selected: 'blue'

    # Creating a ref on a path that is currently a reference should modify
    # the reference, similar to setting an object reference in Javascript
    ref2 = model.ref '_color', 'colors.blue'
    model.get().should.specEql
      colors:
        blue:
          hex: '#0f0'
      _color: ref2
      selected: 'blue'

    # Test setting on a non-keyed reference
    model.set '_color.compliment', 'yellow'
    model.get().should.specEql
      colors:
        blue:
          hex: '#0f0'
          compliment: 'yellow'
      _color: ref2
      selected: 'blue'

  it 'should support getting nested references', ->
    model = new Model
    model.set 'users.1', 'brian'
    model.ref '_session.user', 'users.1'
    model.get('_session.user').should.equal 'brian'

    model.set 'userId', '1'
    model.ref '_session.user', 'users', 'userId'
    model.get('_session.user').should.equal 'brian'

    model.set '_session', userId: 1
    model.ref '_session.user', 'users', '_session.userId'
    model.get('_session.user').should.equal 'brian'

  it 'should support getting and setting a reference to an undefined path', ->
    model = new Model

    model.ref '_color', 'green'
    should.equal undefined, model.get '_color'
    should.equal undefined, model.get '_color.hex'

    model.set '_color.hex', '#0f0'
    model.get('green').should.specEql hex: '#0f0'

    model.del '_color.hex'
    model.get('green').should.specEql {}

    model.del 'green'
    should.equal undefined, model.get 'green'

  it 'should support push', ->
    model = new Model
    model.ref '_items', 'arr'
    model.push '_items', 'item'
    model.get('arr').should.specEql ['item']

  it 'adds a model._getRef method', ->
    model = new Model
    ref = model.ref '_firstNumber', 'numbers.first'
    should.equal model.get('_firstNumber'), undefined
    should.equal model._getRef('_firstNumber'), ref

  it 'does not have an effect after being deleted', ->
    model = new Model
    ref = model.ref '_color', 'colors.green'
    model.set '_color.hex', '#0f0'
    model.get().should.specEql
      colors:
        green:
          hex: '#0f0'
      _color: ref

    model = new Model
    model.ref '_color', 'colors.green'
    model.del '_color'
    model.get().should.specEql {}
    model.set '_color.hex', '#0f0'
    model.get().should.specEql
      _color:
        hex: '#0f0'

  it 'should dereference paths', calls 1, (done) ->
    count = 0
    [model, sockets] = mockSocketModel '0', 'txn', (txn) ->
      txn.slice().should.eql expected[count++]
      sockets._disconnect()
      done()
    ref = model.ref '_color', 'colors.green'
    expected = [transaction.create(
      base: 0, id: '0.1', method: 'set', args: ['colors.green.hex', '#0f0']
    )]
    model.set '_color.hex', '#0f0'

  it 'should emit on both paths when setting under reference', calls 2, (done) ->
    model = new Model
    model.ref '_color', 'colors.green'
    model.on 'set', 'colors.green.*', cb = (prop, value, previous, isLocal) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      should.equal undefined, previous
      isLocal.should.equal true
      done()
    model.on 'set', '_color.*', cb
    model.set '_color.hex', '#0f0'

  it 'should emit on both paths when setting under referenced path', calls 2, (done) ->
    model = new Model
    model.ref '_color', 'colors.green'
    model.on 'set', 'colors.green.*', cb = (prop, value, previous, isLocal) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      should.equal undefined, previous
      isLocal.should.equal true
      done()
    model.on 'set', '_color.*', cb
    model.set 'colors.green.hex', '#0f0'

  it 'should emit on both paths when setting to referenced path', calls 2, (done) ->
    model = new Model
    model.ref '_color', 'colors.green'
    model.on 'set', 'colors.green', cb = (value, previous, isLocal) ->
      value.should.eql hex: '#0f0'
      should.equal undefined, previous
      isLocal.should.equal true
      done()
    model.on 'set', '_color', cb
    model.set 'colors.green', hex: '#0f0'

  it 'should not emit under referenced path after reference is deleted', calls 0, (done) ->
    model = new Model
    model.ref '_color', 'colors.green'
    model.del '_color'
    model.on 'set', 'colors.green.*', done
    model.set '_color.hex', '#0f0'

  it 'should not emit under reference after reference is deleted', calls 0, (done) ->
    model = new Model
    model.ref '_color', 'colors.green'
    model.del '_color'
    model.on 'set', '_color.*', done
    model.set 'colors.green.hex', '#0f0'

  it 'should emit upstream on a reference to a reference', calls 2, (done) ->
    model = new Model
    model.ref '_color', 'colors._green'
    model.ref 'colors._green', 'bestColor'
    model.on 'set', '_color.hex', (value) ->
      value.should.eql '#0f0'
      done()
    model.on 'set', 'colors.*', (path, value) ->
      path.should.eql '_green.hex'
      value.should.eql '#0f0'
      done()
    model.set 'bestColor.hex', '#0f0'

  it 'should emit upstream on a reference to a reference alternate', calls 3, (done) ->
    model = new Model
    model.ref '_room', 'rooms.lobby'
    model.ref '_user', '_room.users.0'
    model.on 'set', '_room.users.0.name', cb = (value) ->
      value.should.eql '#0f0'
      done()
    model.on 'set', '_user.name', cb
    model.on 'set', 'rooms.lobby.users.0.name', cb
    model.set '_user.name', '#0f0'

  it 'should raise an event for each reference to the same path', calls 2, (done) ->
    model = new Model
    model.ref '_color', 'colors.green'
    model.ref '_bestColor', 'colors.green'
    model.on 'set', '_color', done
    model.on 'set', '_bestColor', done
    model.set 'colors.green', {}

  it 'should work on different parts of a nested path', calls 2, (done) ->
    model = new Model
    model.ref '_a', 'w.x.y.z'
    model.ref '_b', 'w.x'
    model.on 'set', '_a', (value) ->
      value.should.eql 'green'
      done()
    model.on 'set', '_b.*', (path, value) ->
      path.should.eql 'y.z'
      value.should.eql 'green'
      done()
    model.set 'w.x.y.z', 'green'

  it 'should emit on both paths when setting under reference with key', calls 2, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref '_color', 'colors', 'colorName'
    model.on 'set', 'colors.green.*', cb = (prop, value, previous, isLocal) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      should.equal undefined, previous
      isLocal.should.equal true
      done()
    model.on 'set', '_color.*', cb
    model.set '_color.hex', '#0f0'

  it 'should emit on both paths when setting under referenced path with key', calls 2, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref '_color', 'colors', 'colorName'
    model.on 'set', 'colors.green.*', cb = (prop, value, previous, isLocal) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      should.equal undefined, previous
      isLocal.should.equal true
      done()
    model.on 'set', '_color.*', cb
    model.set 'colors.green.hex', '#0f0'

  it 'should emit on both paths when setting to referenced path with key', calls 2, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref '_color', 'colors', 'colorName'
    model.on 'set', 'colors.green', cb = (value, previous, isLocal) ->
      value.should.eql hex: '#0f0'
      should.equal undefined, previous
      isLocal.should.equal true
      done()
    model.on 'set', '_color', cb
    model.set 'colors.green', hex: '#0f0'

  it 'should not emit when setting under non-matching key', calls 1, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref '_color', 'colors', 'colorName'
    model.on 'set', '*', done
    model.set 'colors.cream.hex', '#0f0'

  it 'should not emit when setting to non-matching key', calls 1, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref '_color', 'colors', 'colorName'
    model.on 'set', '*', done
    model.set 'colors.cream', hex: '#0f0'

  it 'should emit events with a nested key', calls 2, (done) ->
    model = new Model
    model.set 'users.1', name: 'brian'
    model.set 'userId', '1'
    model.ref '_session.user', 'users', 'userId'
    model.on 'set', '_session.user.name', done
    model.on 'set', 'users.1.name', done
    model.set '_session.user.name', 'nate'

  it 'should emit events with a self-referencing key', calls 3, (done) ->
    model = new Model
    model.ref '_room', 'rooms.1'
    model.set '_session.userId', 0
    model.ref '_session.user', '_room.users', '_session.userId'
    model.on 'set', 'rooms.1.users.0.name', cb = (value) ->
      value.should.eql 'Bob'
      done()
    model.on 'set', '_room.users.0.name', cb
    model.on 'set', '_session.user.name', cb
    model.set '_session.user.name', 'Bob'

  it 'supports specifying path via model.at', ->
    model = new Model
    color = model.at '_color'
    ref = color.at('favorite').ref 'green'
    color.set 'favorite.hex', '#0f0'
    color.get('favorite').should.specEql hex: '#0f0'
    model.get().should.specEql
      _color:
        favorite: ref
      green:
        hex: '#0f0'
