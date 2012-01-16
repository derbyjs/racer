Model = require '../src/Model'
should = require 'should'

describe 'Model.at', ->

 it 'supports being created and accessed', ->
    model = new Model

    model.at('path').path().should.equal 'path'
    model.at('path').at('').path().should.equal 'path'
    model.at('the.path').at('sub').at(0).path().should.equal 'the.path.sub.0'

  it 'parent traverses up', ->
    model = new Model

    model.parent().should.equal model
    model.parent(3).should.equal model
    model.parent().path().should.equal ''
    model.parent(3).path().should.equal ''

    model.at('path').parent().path().should.equal ''
    model.at('path.fun').parent().path().should.equal 'path'
    model.at('path.fun.times').parent(1).path().should.equal 'path.fun'
    model.at('path.fun.times').parent(2).path().should.equal 'path'
    model.at('path.fun').parent(4).path().should.equal ''

  it 'supports get', ->
    model = new Model
    model.set 'colors',
      green: {hex: '#0f0'}

    colors = model.at('colors')
  
    colors.get().should.specEql green: {hex: '#0f0'}
    colors.at('green').at('hex').get().should.equal '#0f0'
    colors.get('green.hex').should.equal '#0f0'

    should.equal undefined, colors.at('red').get()
    should.equal undefined, colors.at('red').at('hex').get()
    should.equal undefined, colors.get('red')

  it 'supports set', ->
    model = new Model
    colors = model.at 'colors'
  
    colors.set 'green', '#0f0'
    colors.get('green').should.equal '#0f0'
    model.get('colors').should.specEql green: '#0f0'
    
    colors.set red: '#f00'
    colors.get('red').should.equal '#f00'
    model.get('colors').should.specEql red: '#f00'

    colors.set {blue: '#00f'}, ->
    colors.get('blue').should.equal '#00f'
    model.get('colors').should.specEql blue: '#00f'

    colors.at('yellow').set '#ff0'
    model.get('colors.yellow').should.equal '#ff0'

  it 'supports del', ->
    model = new Model
    colors = model.at 'colors'

    colors.set 'green', '#0f0'
    colors.get('green').should.equal '#0f0'

    colors.del()
    should.equal undefined, colors.get()
    model.get().should.specEql {}

    model.set 'colors',
      red: '#f00'
      green: '#0f0'
      blue: '#00f'
    colors.del 'red'
    model.get('colors').should.specEql
      green: '#0f0'
      blue: '#00f'

    colors.del 'green', ->
    model.get('colors').should.specEql
      blue: '#00f'

    colors.del ->
    should.equal undefined, colors.get()
    model.get().should.specEql {}

    colors.del 'none'
    model.get().should.specEql {}

  it 'supports setNull', ->
    model = new Model
    colors = model.at 'colors'

    colors.setNull 'green', '#0f0'
    colors.get('green').should.equal '#0f0'
    model.get('colors').should.specEql green: '#0f0'

    colors.setNull red: '#f00'
    colors.get('green').should.equal '#0f0'
    model.get('colors').should.specEql green: '#0f0'

    colors.set null
    colors.setNull red: '#f00'
    colors.get('red').should.equal '#f00'
    model.get('colors').should.specEql red: '#f00'

    colors.set null
    colors.set {blue: '#00f'}, ->
    colors.get('blue').should.equal '#00f'
    model.get('colors').should.specEql blue: '#00f'

  it 'supports incr', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.incr 'i'
    stuff.get('i').should.equal 1
    model.get('stuff.i').should.equal 1

    stuff.incr 'i', ->
    stuff.get('i').should.equal 2
    model.get('stuff.i').should.equal 2

    stuff.incr 'i', 2, ->
    stuff.get('i').should.equal 4
    model.get('stuff.i').should.equal 4

    i = stuff.at 'i'
    i.incr()
    i.get().should.equal 5
    model.get('stuff.i').should.equal 5

    i = stuff.at 'i'
    i.incr ->
    i.get().should.equal 6
    model.get('stuff.i').should.equal 6

    i.incr -6
    i.get().should.equal 0
    model.get('stuff.i').should.equal 0

    i.incr -1, ->
    i.get().should.equal -1
    model.get('stuff.i').should.equal -1

  it 'supports push', ->
    model = new Model
    stuff = model.at 'stuff'

    # If pushing to an undefined path, it creates an array
    stuff.push 'green', 'red'
    model.get().should.specEql
      stuff: ['green', 'red']

    # If pushing to an object, the first argument must be a property path
    stuff.set {}
    stuff.push 'names', 'Sam', 'Jill'
    model.get().should.specEql
      stuff: names: ['Sam', 'Jill']

    stuff.push 'names', 'Ben', ->
    stuff.get('names').should.specEql ['Sam', 'Jill', 'Ben']

  it 'supports unshift', ->
    model = new Model
    stuff = model.at 'stuff'

    # If unshifting to an undefined path, it creates an array
    stuff.unshift 'green', 'red'
    model.get().should.specEql
      stuff: ['green', 'red']

    # If unshifting to an object, the first argument must be a property path
    stuff.set {}
    stuff.unshift 'names', 'Sam', 'Jill'
    model.get().should.specEql
      stuff: names: ['Sam', 'Jill']

    stuff.unshift 'names', 'Ben', ->
    stuff.get('names').should.specEql ['Ben', 'Sam', 'Jill']

  it 'supports insert', ->
    model = new Model
    stuff = model.at 'stuff'

    # If inserting on an undefined path, it creates an array
    stuff.insert 0, 'green', 'red'
    model.get().should.specEql
      stuff: ['green', 'red']
    
    stuff.insert '1', 'yellow'
    model.get().should.specEql
      stuff: ['green', 'yellow', 'red']

    # If inserting to an object, the first argument must be a property path
    stuff.set {}
    stuff.insert 'names', 0, 'Sam', 'Jill'
    model.get().should.specEql
      stuff: names: ['Sam', 'Jill']

    stuff.insert 'names', 1, 'Ben', ->
    stuff.get('names').should.specEql ['Sam', 'Ben', 'Jill']

    stuff.insert 'names', '2', 'Karen', ->
    stuff.get('names').should.specEql ['Sam', 'Ben', 'Karen', 'Jill']

  it 'supports pop', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.set ['green', 'red']
    stuff.pop().should.equal 'red'
    stuff.get().should.specEql ['green']
    model.get().should.specEql stuff: ['green']

    stuff.pop(->).should.equal 'green'
    model.get().should.specEql stuff: []

    should.equal undefined, stuff.pop()
    model.get().should.specEql stuff: []

    stuff.set names: ['Sam', 'Jill']
    stuff.pop('names').should.equal 'Jill'
    model.get().should.specEql stuff: names: ['Sam']

    stuff.pop('names', ->).should.equal 'Sam'
    model.get().should.specEql stuff: names: []

  it 'supports shift', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.set ['green', 'red']
    stuff.shift().should.equal 'green'
    stuff.get().should.specEql ['red']
    model.get().should.specEql stuff: ['red']

    stuff.shift(->).should.equal 'red'
    model.get().should.specEql stuff: []

    should.equal undefined, stuff.shift()
    model.get().should.specEql stuff: []

    stuff.set names: ['Sam', 'Jill']
    stuff.shift('names').should.equal 'Sam'
    model.get().should.specEql stuff: names: ['Jill']

    stuff.shift('names', ->).should.equal 'Jill'
    model.get().should.specEql stuff: names: []

  it 'supports remove', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.set ['green', 'red', 'blue', 'yellow', 'purple']
    stuff.remove(2).should.specEql ['blue']
    stuff.get().should.specEql ['green', 'red', 'yellow', 'purple']
    model.get().should.specEql stuff: ['green', 'red', 'yellow', 'purple']

    stuff.remove(1, ->).should.specEql ['red']
    stuff.get().should.specEql ['green', 'yellow', 'purple']

    stuff.remove('0', 2).should.specEql ['green', 'yellow']
    stuff.get().should.specEql ['purple']

    stuff.remove(0, 1, ->).should.specEql ['purple']
    stuff.get().should.specEql []

    stuff.set names: ['Sam', 'Jill', 'Ben', 'Karen', 'Pete', 'Sally']
    stuff.remove('names', 0).should.specEql ['Sam']
    stuff.get('names').should.specEql ['Jill', 'Ben', 'Karen', 'Pete', 'Sally']
    model.get().should.specEql stuff: names: ['Jill', 'Ben', 'Karen', 'Pete', 'Sally']

    stuff.remove('names', 1, ->).should.specEql ['Ben']
    stuff.get('names').should.specEql ['Jill', 'Karen', 'Pete', 'Sally']

    stuff.remove('names', 1, 2).should.specEql ['Karen', 'Pete']
    stuff.get('names').should.specEql ['Jill', 'Sally']

    stuff.remove('names', 0, 2, ->).should.specEql ['Jill', 'Sally']
    stuff.get().should.specEql names: []

  it 'supports move', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.set ['green', 'red', 'blue', 'yellow']
    stuff.move(1, 2).should.equal 'red'
    stuff.get().should.specEql ['green', 'blue', 'red', 'yellow']

    stuff.move(0, 3, ->).should.equal 'green'
    stuff.get().should.specEql ['blue', 'red', 'yellow', 'green']

    stuff.move('0', 1).should.equal 'blue'
    stuff.get().should.specEql ['red', 'blue', 'yellow', 'green']

    stuff.set names: ['Sam', 'Jill', 'Ben']
    stuff.move('names', 2, 0).should.equal 'Ben'
    stuff.get('names').should.specEql ['Ben', 'Sam', 'Jill']
    model.get().should.specEql stuff: names: ['Ben', 'Sam', 'Jill']

    stuff.move('names', 1, 0, ->).should.equal 'Sam'
    stuff.get('names').should.specEql ['Sam', 'Ben', 'Jill']

  it 'supports event subscription', (done) ->
    model = new Model
    color = model.at 'color'

    color.on 'set', (value, previous, isLocal, pass) ->
      value.should.equal 'green'
      should.equal undefined, previous
      isLocal.should.be.true
      pass.should.equal 'hi'
      done()

    color.pass('hi').set 'green'

  it 'supports event subscription to subpath', (done) ->
    model = new Model
    color = model.at 'color'

    color.on 'set', 'hex', (value, previous, isLocal, pass) ->
      value.should.equal '#0f0'
      should.equal undefined, previous
      isLocal.should.be.true
      should.equal undefined, pass
      done()

    color.set 'hex', '#0f0'

  it 'supports event subscription to subpattern', (done) ->
    model = new Model
    colors = model.at 'colors'

    model.set 'colors.5.name', 'blue'

    colors.on 'set', '*.name', (id, value, previous, isLocal, pass) ->
      id.should.equal '5'
      value.should.equal 'green'
      previous.should.equal 'blue'
      isLocal.should.be.true
      should.equal undefined, pass
      done()

    model.set 'colors.5.name', 'green'
