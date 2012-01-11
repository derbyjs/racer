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
    model.ref 'numbers', 'info.numbers'
    model.ref 'number', 'numbers', 'numKey'

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
  
  it 'should support setting', ->
    model = new Model
    
    ref = model.ref 'color', 'colors', 'selected'
    model.get().should.specEql
      color: ref
    
    # Set a key value
    model.set 'selected', 'blue'
    model.get().should.specEql
      color: ref
      selected: 'blue'

    # Setting a property on a reference should update the referenced object
    model.set 'color.hex', '#0f0'
    model.get().should.specEql
      colors:
        blue:
          hex: '#0f0'
      color: ref
      selected: 'blue'

    # Creating a ref on a path that is currently a reference should modify
    # the reference, similar to setting an object reference in Javascript
    ref2 = model.ref 'color', 'colors.blue'
    model.get().should.specEql
      colors:
        blue:
          hex: '#0f0'
      color: ref2
      selected: 'blue'

    # Test setting on a non-keyed reference
    model.set 'color.compliment', 'yellow'
    model.get().should.specEql
      colors:
        blue:
          hex: '#0f0'
          compliment: 'yellow'
      color: ref2
      selected: 'blue'

  it 'should support getting nested references', ->
    model = new Model
    model.set 'users.1', 'brian'
    model.ref 'session.user', 'users.1'
    model.get('session.user').should.equal 'brian'

    model.set 'userId', '1'
    model.ref 'session.user', 'users', 'userId'
    model.get('session.user').should.equal 'brian'

    model.set 'session', userId: 1
    model.ref 'session.user', 'users', 'session.userId'
    model.get('session.user').should.equal 'brian'

  it 'should support getting and setting a reference to an undefined path', ->
    model = new Model

    model.ref 'color', 'green'
    should.equal undefined, model.get 'color'
    should.equal undefined, model.get 'color.hex'

    model.set 'color.hex', '#0f0'
    model.get('green').should.specEql hex: '#0f0'

    model.del 'color.hex'
    model.get('green').should.specEql {}

    model.del 'green'
    should.equal undefined, model.get 'green'

  it 'should support push', ->
    model = new Model
    model.ref 'items', 'arr'
    model.push 'items', 'item'
    model.get('arr').should.specEql ['item']

  it 'adds a model.getRef method', ->
    model = new Model
    ref = model.ref 'firstNumber', 'numbers.first'
    should.equal model.get('firstNumber'), undefined
    should.equal model.getRef('firstNumber'), ref

  it 'does not have an effect after being deleted', ->
    model = new Model
    ref = model.ref 'color', 'colors.green'
    model.set 'color.hex', '#0f0'
    model.get().should.specEql
      colors:
        green:
          hex: '#0f0'
      color: ref

    model = new Model
    model.ref 'color', 'colors.green'
    model.del 'color'
    model.set 'color.hex', '#0f0'
    model.get().should.specEql
      color:
        hex: '#0f0'

  it 'should dereference paths', calls 2, (done) ->
    count = 0
    [sockets, model] = mockSocketModel '0', 'txn', (txn) ->
      txn.slice().should.eql expected[count++]
      sockets._disconnect()
      done()
    ref = model.ref 'color', 'colors.green'
    expected = [
      transaction.create(base: 0, id: '0.0', method: 'set', args: ['color', ref])
      transaction.create(base: 0, id: '0.1', method: 'set', args: ['colors.green.hex', '#0f0'])
    ]
    model.set 'color.hex', '#0f0'

  it 'should emit on both paths when setting under reference', calls 2, (done) ->
    model = new Model
    model.ref 'color', 'colors.green'
    model.on 'set', 'colors.green.*', cb = (prop, value, out, isLocal) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      out.should.equal '#0f0'
      isLocal.should.equal true
      done()
    model.on 'set', 'color.*', cb
    model.set 'color.hex', '#0f0'

  it 'should emit on both paths when setting under referenced path', calls 2, (done) ->
    model = new Model
    model.ref 'color', 'colors.green'
    model.on 'set', 'colors.green.*', cb = (prop, value, out, isLocal) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      out.should.equal '#0f0'
      isLocal.should.equal true
      done()
    model.on 'set', 'color.*', cb
    model.set 'colors.green.hex', '#0f0'

  it 'should emit on both paths when setting to referenced path', calls 2, (done) ->
    model = new Model
    model.ref 'color', 'colors.green'
    model.on 'set', 'colors.green', cb = (value, out, isLocal) ->
      value.should.eql hex: '#0f0'
      out.should.eql hex: '#0f0'
      isLocal.should.equal true
      done()
    model.on 'set', 'color', cb
    model.set 'colors.green', hex: '#0f0'

  it 'should not emit under referenced path after reference is deleted', calls 0, (done) ->
    model = new Model
    model.ref 'color', 'colors.green'
    model.del 'color'
    model.on 'set', 'colors.green.*', done
    model.set 'color.hex', '#0f0'

  it 'should not emit under reference after reference is deleted', calls 0, (done) ->
    model = new Model
    model.ref 'color', 'colors.green'
    model.del 'color'
    model.on 'set', 'color.*', done
    model.set 'colors.green.hex', '#0f0'

  it 'should emit upstream on a reference to a reference', calls 2, (done) ->
    model = new Model
    model.ref 'color', 'colors.green'
    model.ref 'colors.green', 'bestColor'
    model.on 'set', 'color.hex', (value) ->
      value.should.eql '#0f0'
      done()
    model.on 'set', 'colors.*', (path, value) ->
      path.should.eql 'green.hex'
      value.should.eql '#0f0'
      done()
    model.set 'bestColor.hex', '#0f0'

  it 'should emit upstream on a reference to a reference (private)', calls 3, (done) ->
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
    model.ref 'color', 'colors.green'
    model.ref 'bestColor', 'colors.green'
    model.on 'set', 'color', done
    model.on 'set', 'bestColor', done
    model.set 'colors.green', {}

  it 'should work on different parts of a nested path', calls 2, (done) ->
    model = new Model
    model.ref 'a', 'w.x.y.z'
    model.ref 'b', 'w.x'
    model.on 'set', 'a', (value) ->
      value.should.eql 'green'
      done()
    model.on 'set', 'b.*', (path, value) ->
      path.should.eql 'y.z'
      value.should.eql 'green'
      done()
    model.set 'w.x.y.z', 'green'

  it 'should emit on both paths when setting under reference with key', calls 2, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref 'color', 'colors', 'colorName'
    model.on 'set', 'colors.green.*', cb = (prop, value, out, isLocal) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      out.should.equal '#0f0'
      isLocal.should.equal true
      done()
    model.on 'set', 'color.*', cb
    model.set 'color.hex', '#0f0'

  it 'should emit on both paths when setting under referenced path with key', calls 2, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref 'color', 'colors', 'colorName'
    model.on 'set', 'colors.green.*', cb = (prop, value, out, isLocal) ->
      prop.should.equal 'hex'
      value.should.equal '#0f0'
      out.should.equal '#0f0'
      isLocal.should.equal true
      done()
    model.on 'set', 'color.*', cb
    model.set 'colors.green.hex', '#0f0'

  it 'should emit on both paths when setting to referenced path with key', calls 2, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref 'color', 'colors', 'colorName'
    model.on 'set', 'colors.green', cb = (value, out, isLocal) ->
      value.should.eql hex: '#0f0'
      out.should.eql hex: '#0f0'
      isLocal.should.equal true
      done()
    model.on 'set', 'color', cb
    model.set 'colors.green', hex: '#0f0'

  it 'should not emit when setting under non-matching key', calls 1, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref 'color', 'colors', 'colorName'
    model.on 'set', '*', done
    model.set 'colors.cream.hex', '#0f0'

  it 'should not emit when setting to non-matching key', calls 1, (done) ->
    model = new Model
    model.set 'colorName', 'green'
    model.ref 'color', 'colors', 'colorName'
    model.on 'set', '*', done
    model.set 'colors.cream', hex: '#0f0'

  it 'should emit events with a nested key', calls 2, (done) ->
    model = new Model
    model.set 'users.1', name: 'brian'
    model.set 'userId', '1'
    model.ref 'session.user', 'users', 'userId'
    model.on 'set', 'session.user.name', done
    model.on 'set', 'users.1.name', done
    model.set 'session.user.name', 'nate'

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
