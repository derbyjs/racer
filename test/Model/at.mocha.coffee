{expect} = require '../util'
{BrowserModel: Model} = require '../util/model'

describe 'Model.at', ->

  it 'supports being created and accessed', ->
    model = new Model

    expect(model.at('path').path()).to.equal 'path'
    expect(model.at('path').at('').path()).to.equal 'path'
    expect(model.at('the.path').at('sub').at(0).path()).to.equal 'the.path.sub.0'

  it 'parent traverses up', ->
    model = new Model

    expect(model.parent()).to.equal model
    expect(model.parent 3).to.equal model
    expect(model.parent().path()).to.equal ''
    expect(model.parent(3).path()).to.equal ''

    expect(model.at('path').parent().path()).to.equal ''
    expect(model.at('path.fun').parent().path()).to.equal 'path'
    expect(model.at('path.fun.times').parent(1).path()).to.equal 'path.fun'
    expect(model.at('path.fun.times').parent(2).path()).to.equal 'path'
    expect(model.at('path.fun').parent(4).path()).to.equal ''

  it 'supports get', ->
    model = new Model
    model.set 'colors',
      green: {hex: '#0f0'}

    colors = model.at('colors')

    expect(colors.get()).to.specEql green: {hex: '#0f0'}
    expect(colors.at('green').at('hex').get()).to.equal '#0f0'
    expect(colors.get 'green.hex').to.equal '#0f0'

    expect(colors.at('red').get()).to.equal undefined
    expect(colors.at('red').at('hex').get()).to.equal undefined
    expect(colors.get 'red').to.equal undefined

  it 'supports set', ->
    model = new Model
    colors = model.at 'colors'

    colors.set 'green', '#0f0'
    expect(colors.get 'green').to.equal '#0f0'
    expect(model.get 'colors').to.specEql green: '#0f0'

    colors.set red: '#f00'
    expect(colors.get 'red').to.equal '#f00'
    expect(model.get 'colors').to.specEql red: '#f00'

    colors.set {blue: '#00f'}, ->
    expect(colors.get 'blue').to.equal '#00f'
    expect(model.get 'colors').to.specEql blue: '#00f'

    colors.at('yellow').set '#ff0'
    expect(model.get 'colors.yellow').to.equal '#ff0'

  it 'supports del', ->
    model = new Model
    colors = model.at 'colors'

    colors.set 'green', '#0f0'
    expect(colors.get 'green').to.equal '#0f0'

    colors.del()
    expect(colors.get()).to.equal undefined
    expect(model.get()).to.specEql {}

    model.set 'colors',
      red: '#f00'
      green: '#0f0'
      blue: '#00f'
    colors.del 'red'
    expect(model.get 'colors').to.specEql
      green: '#0f0'
      blue: '#00f'

    colors.del 'green', ->
    expect(model.get 'colors').to.specEql
      blue: '#00f'

    colors.del ->
    expect(colors.get()).to.equal undefined
    expect(model.get()).to.specEql {}

    colors.del 'none'
    expect(model.get()).to.specEql {}

  it 'supports setNull', ->
    model = new Model
    colors = model.at 'colors'

    colors.setNull 'green', '#0f0'
    expect(colors.get 'green').to.equal '#0f0'
    expect(model.get 'colors').to.specEql green: '#0f0'

    colors.setNull red: '#f00'
    expect(colors.get 'green').to.equal '#0f0'
    expect(model.get 'colors').to.specEql green: '#0f0'

    colors.set null
    colors.setNull red: '#f00'
    expect(colors.get 'red').to.equal '#f00'
    expect(model.get 'colors').to.specEql red: '#f00'

    colors.set null
    colors.set {blue: '#00f'}, ->
    expect(colors.get 'blue').to.equal '#00f'
    expect(model.get 'colors').to.specEql blue: '#00f'

  it 'supports incr', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.incr 'i'
    expect(stuff.get 'i').to.equal 1
    expect(model.get 'stuff.i').to.equal 1

    stuff.incr 'i', ->
    expect(stuff.get 'i').to.equal 2
    expect(model.get 'stuff.i').to.equal 2

    stuff.incr 'i', 2, ->
    expect(stuff.get 'i').to.equal 4
    expect(model.get 'stuff.i').to.equal 4

    i = stuff.at 'i'
    i.incr()
    expect(i.get()).to.equal 5
    expect(model.get 'stuff.i').to.equal 5

    i = stuff.at 'i'
    i.incr ->
    expect(i.get()).to.equal 6
    expect(model.get 'stuff.i').to.equal 6

    i.incr -6
    expect(i.get()).to.equal 0
    expect(model.get 'stuff.i').to.equal 0

    i.incr -1, ->
    expect(i.get()).to.equal -1
    expect(model.get 'stuff.i').to.equal -1

  it 'supports add', ->
    model = new Model
    stuff = model.at 'stuff'

    id = stuff.add {a: 1}
    expected = {}
    expected[id] = {id, a: 1}
    expect(stuff.get()).to.specEql expected
    expect(model.get 'stuff').to.specEql expected

    id = stuff.add 'foo', {b: 1}
    expect(stuff.get 'foo.' + id).to.specEql {id, b: 1}

  it 'supports push', ->
    model = new Model
    stuff = model.at 'stuff'

    # If pushing to an undefined path, it creates an array
    stuff.push 'green', 'red'
    expect(model.get()).to.specEql
      stuff: ['green', 'red']

    # If pushing to an object, the first argument must be a property path
    stuff.set {}
    stuff.push 'names', 'Sam', 'Jill'
    expect(model.get()).to.specEql
      stuff: names: ['Sam', 'Jill']

    stuff.push 'names', 'Ben', ->
    expect(stuff.get 'names').to.specEql ['Sam', 'Jill', 'Ben']

  it 'supports unshift', ->
    model = new Model
    stuff = model.at 'stuff'

    # If unshifting to an undefined path, it creates an array
    stuff.unshift 'green', 'red'
    expect(model.get()).to.specEql
      stuff: ['green', 'red']

    # If unshifting to an object, the first argument must be a property path
    stuff.set {}
    stuff.unshift 'names', 'Sam', 'Jill'
    expect(model.get()).to.specEql
      stuff: names: ['Sam', 'Jill']

    stuff.unshift 'names', 'Ben', ->
    expect(stuff.get 'names').to.specEql ['Ben', 'Sam', 'Jill']

  it 'supports insert', ->
    model = new Model
    stuff = model.at 'stuff'

    # If inserting on an undefined path, it creates an array
    stuff.insert 0, 'green', 'red'
    expect(model.get()).to.specEql
      stuff: ['green', 'red']

    stuff.insert '1', 'yellow'
    expect(model.get()).to.specEql
      stuff: ['green', 'yellow', 'red']

    # If inserting to an object, the first argument must be a property path
    stuff.set {}
    stuff.insert 'names', 0, 'Sam', 'Jill'
    expect(model.get()).to.specEql
      stuff: names: ['Sam', 'Jill']

    stuff.insert 'names', 1, 'Ben', ->
    expect(stuff.get 'names').to.specEql ['Sam', 'Ben', 'Jill']

    stuff.insert 'names', '2', 'Karen', ->
    expect(stuff.get 'names').to.specEql ['Sam', 'Ben', 'Karen', 'Jill']

  it 'supports pop', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.set ['green', 'red']
    expect(stuff.pop()).to.equal 'red'
    expect(stuff.get()).to.specEql ['green']
    expect(model.get()).to.specEql stuff: ['green']

    expect(stuff.pop ->).to.equal 'green'
    expect(model.get()).to.specEql stuff: []

    expect(stuff.pop()).to.equal undefined
    expect(model.get()).to.specEql stuff: []

    stuff.set names: ['Sam', 'Jill']
    expect(stuff.pop 'names').to.equal 'Jill'
    expect(model.get()).to.specEql stuff: names: ['Sam']

    expect(stuff.pop 'names', ->).to.equal 'Sam'
    expect(model.get()).to.specEql stuff: names: []

  it 'supports shift', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.set ['green', 'red']
    expect(stuff.shift()).to.equal 'green'
    expect(stuff.get()).to.specEql ['red']
    expect(model.get()).to.specEql stuff: ['red']

    expect(stuff.shift ->).to.equal 'red'
    expect(model.get()).to.specEql stuff: []

    expect(stuff.shift()).to.equal undefined
    expect(model.get()).to.specEql stuff: []

    stuff.set names: ['Sam', 'Jill']
    expect(stuff.shift 'names').to.equal 'Sam'
    expect(model.get()).to.specEql stuff: names: ['Jill']

    expect(stuff.shift 'names', ->).to.equal 'Jill'
    expect(model.get()).to.specEql stuff: names: []

  it 'supports remove', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.set ['green', 'red', 'blue', 'yellow', 'purple']
    expect(stuff.remove 2).to.specEql ['blue']
    expect(stuff.get()).to.specEql ['green', 'red', 'yellow', 'purple']
    expect(model.get()).to.specEql stuff: ['green', 'red', 'yellow', 'purple']

    expect(stuff.remove 1, ->).to.specEql ['red']
    expect(stuff.get()).to.specEql ['green', 'yellow', 'purple']

    expect(stuff.remove '0', 2).to.specEql ['green', 'yellow']
    expect(stuff.get()).to.specEql ['purple']

    expect(stuff.remove 0, 1, ->).to.specEql ['purple']
    expect(stuff.get()).to.specEql []

    stuff.set names: ['Sam', 'Jill', 'Ben', 'Karen', 'Pete', 'Sally']
    expect(stuff.remove 'names', 0).to.specEql ['Sam']
    expect(stuff.get 'names').to.specEql ['Jill', 'Ben', 'Karen', 'Pete', 'Sally']
    expect(model.get()).to.specEql stuff: names: ['Jill', 'Ben', 'Karen', 'Pete', 'Sally']

    expect(stuff.remove 'names', 1, ->).to.specEql ['Ben']
    expect(stuff.get 'names').to.specEql ['Jill', 'Karen', 'Pete', 'Sally']

    expect(stuff.remove 'names', 1, 2).to.specEql ['Karen', 'Pete']
    expect(stuff.get 'names').to.specEql ['Jill', 'Sally']

    expect(stuff.remove 'names', 0, 2, ->).to.specEql ['Jill', 'Sally']
    expect(stuff.get()).to.specEql names: []

  it 'supports move', ->
    model = new Model
    stuff = model.at 'stuff'

    stuff.set ['green', 'red', 'blue', 'yellow']
    expect(stuff.move 1, 2).to.eql ['red']
    expect(stuff.get()).to.specEql ['green', 'blue', 'red', 'yellow']

    expect(stuff.move 0, 3, ->).to.eql ['green']
    expect(stuff.get()).to.specEql ['blue', 'red', 'yellow', 'green']

    expect(stuff.move '0', 1).to.eql ['blue']
    expect(stuff.get()).to.specEql ['red', 'blue', 'yellow', 'green']

    stuff.set names: ['Sam', 'Jill', 'Ben']
    expect(stuff.move 'names', 2, 0).to.eql ['Ben']
    expect(stuff.get 'names').to.specEql ['Ben', 'Sam', 'Jill']
    expect(model.get()).to.specEql stuff: names: ['Ben', 'Sam', 'Jill']

    expect(stuff.move 'names', 1, 0, ->).to.eql ['Sam']
    expect(stuff.get 'names').to.specEql ['Sam', 'Ben', 'Jill']

  it 'supports event subscription', (done) ->
    model = new Model
    color = model.at 'color'

    color.on 'set', (value, previous, isLocal, pass) ->
      expect(value).to.equal 'green'
      expect(previous).to.equal undefined
      expect(isLocal).to.be.true
      expect(pass).to.equal 'hi'
      done()

    color.pass('hi').set 'green'

  it 'supports event subscription to subpath', (done) ->
    model = new Model
    color = model.at 'color'

    color.on 'set', 'hex', (value, previous, isLocal, pass) ->
      expect(value).to.equal '#0f0'
      expect(previous).to.equal undefined
      expect(isLocal).to.be.true
      expect(pass).to.equal undefined
      done()

    color.set 'hex', '#0f0'

  it 'supports event subscription to subpattern', (done) ->
    model = new Model
    colors = model.at 'colors'

    model.set 'colors.5.name', 'blue'

    colors.on 'set', '*.name', (id, value, previous, isLocal, pass) ->
      expect(id).to.equal '5'
      expect(value).to.equal 'green'
      expect(previous).to.equal 'blue'
      expect(isLocal).to.be.true
      expect(pass).to.equal undefined
      done()

    model.set 'colors.5.name', 'green'
