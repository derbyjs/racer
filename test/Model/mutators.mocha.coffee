{expect} = require '../util'
{BrowserModel: Model} = require '../util/model'

describe 'Model mutators', ->

  it 'get should return the adapter data when there are no pending transactions', ->
    model = new Model
    model._memory._data = world: {a: 1}
    expect(model.get()).to.eql {a: 1}

  it 'test speculative value of set', ->
    model = new Model
    model._clientId = '0'

    previous = model.set 'color', 'green'
    expect(previous).to.equal undefined
    expect(model.get 'color').to.eql 'green'

    previous = model.set 'color', 'red'
    expect(previous).to.equal 'green'
    expect(model.get 'color').to.eql 'red'

    model.set 'info.numbers', first: 2, second: 10
    expect(model.get()).to.specEql
      color: 'red'
      info:
        numbers:
          id: 'numbers'
          first: 2
          second: 10
    expect(model._memory._data).to.specEql world: {}

    model.set 'info.numbers.third', 13
    expect(model.get()).to.specEql
      color: 'red'
      info:
        numbers:
          id: 'numbers'
          first: 2
          second: 10
          third: 13
    expect(model._memory._data).to.specEql world: {}

    model._removeTxn '0.1'
    model._removeTxn '0.2'
    expect(model.get()).to.specEql
      color: 'green'
      info:
        numbers:
          id: 'numbers'
          third: 13
    expect(model._memory._data).to.specEql world: {}

  "speculative mutations of an existing object should not modify the adapter's underlying presentation of that object": ->
    model = new Model
    model._memory._data = world: {obj: {}}
    expect(model._memory._data).to.specEql world: {obj: {}}
    model.set 'obj.a', 'b'
    expect(model._memory._data).to.specEql world: {obj: {}}

  it 'test speculative value of del', ->
    model = new Model
    model._clientId = '0'
    model._memory._data =
      world:
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10

    previous = model.del 'color'
    expect(previous).to.eql 'green'
    expect(model.get()).to.specEql
      info:
        numbers:
          first: 2
          second: 10

    expect(model._memory._data).to.specEql
      world:
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10

    model.set 'color', 'red'
    expect(model.get()).to.specEql
      color: 'red'
      info:
        numbers:
          first: 2
          second: 10

    model.del 'color'
    expect(model.get()).to.specEql
      info:
        numbers:
          first: 2
          second: 10

    model.del 'info.numbers'
    expect(model.get()).to.specEql
      info: {}

    expect(model._memory._data).to.specEql
      world:
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10

    # Make sure deleting something that doesn't exist isn't a problem
    model.del 'a.b.c'

  it 'test speculative incr', ->
    model = new Model

    # Should be able to increment unset path
    val = model.incr 'count'
    expect(model.get 'count').to.eql 1
    expect(val).to.eql 1

    # Default increment should be 1
    val = model.incr 'count'
    expect(model.get 'count').to.eql 2
    expect(val).to.eql 2

    # Should be able to increment by another number
    val = model.incr 'count', -2
    expect(model.get 'count').to.eql 0
    expect(val).to.eql 0

    # Incrementing by zero should work
    val = model.incr 'count', 0
    expect(model.get 'count').to.eql 0
    expect(val).to.eql 0

  it 'test speculative add', ->
    model = new Model

    id = model.add 'colors', {green: '#0f0'}
    expected = {}
    expected[id] = {id, green: '#0f0'}
    expect(model.get 'colors').to.specEql expected

  it 'test speculative push', ->
    model = new Model

    model.push 'colors', 'green'
    expect(model.get 'colors').to.specEql ['green']
    expect(model._memory._data).to.specEql world: {}

  it 'model push should instantiate an undefined path to a new array and insert new members at the end', ->
    model = new Model
    init = model.get 'colors'
    expect(init).to.equal undefined
    out = model.push 'colors', 'green'
    expect(out).to.eql 1
    final = model.get 'colors'
    expect(final).to.specEql ['green']

  it 'model pop should remove a member from an array', ->
    model = new Model
    init = model.get 'colors'
    expect(init).to.equal undefined
    model.push 'colors', 'green'
    interim = model.get 'colors'
    expect(interim).to.specEql ['green']
    out = model.pop 'colors'
    expect(out).to.eql 'green'
    final = model.get 'colors'
    expect(final).to.specEql []

  it 'model unshift should instantiate an undefined path to a new array and insert new members at the beginning', ->
    model = new Model
    init = model.get 'colors'
    expect(init).to.equal undefined
    out = model.unshift 'colors', 'green'
    expect(out).to.eql 1
    interim = model.get 'colors'
    expect(interim).to.specEql ['green']
    out = model.unshift 'colors', 'red', 'orange'
    expect(out).to.eql 3
    final = model.get 'colors'
    expect(final).to.specEql ['red', 'orange', 'green']

  it 'model shift should remove the first member from an array', ->
    model = new Model
    init = model.get 'colors'
    expect(init).to.equal undefined
    out = model.unshift 'colors', 'green', 'blue'
    expect(out).to.eql 2
    interim = model.get 'colors'
    expect(interim).to.specEql ['green', 'blue']
    out = model.shift 'colors'
    expect(out).to.eql 'green'
    final = model.get 'colors'
    expect(final).to.specEql ['blue']

  it 'insert should work on an array, with a valid index', ->
    model = new Model
    model.push 'colors', 'green'
    out = model.insert 'colors', 0, 'red', 'yellow'
    expect(out).to.eql 3
    expect(model.get 'colors').to.specEql ['red', 'yellow', 'green']

  it 'insert should work on an array index path', ->
    model = new Model
    model.push 'colors', 'green'
    out = model.insert 'colors.0', 'red', 'yellow'
    expect(out).to.eql 3
    expect(model.get 'colors').to.specEql ['red', 'yellow', 'green']

  it 'remove should work on an array, with a valid index', ->
    model = new Model
    model.push 'colors', 'red', 'orange', 'yellow', 'green', 'blue', 'violet'
    out = model.remove 'colors', 1, 4
    expect(out).to.specEql ['orange', 'yellow', 'green', 'blue']
    expect(model.get 'colors').to.specEql ['red', 'violet']

  it 'remove should work on an array index path', ->
    model = new Model
    model.push 'colors', 'red', 'orange', 'yellow', 'green', 'blue', 'violet'
    out = model.remove 'colors.1', 4
    expect(out).to.specEql ['orange', 'yellow', 'green', 'blue']
    expect(model.get 'colors').to.specEql ['red', 'violet']

  it 'move should work on an array, with a valid index', ->
    model = new Model
    model.push 'colors', 'red', 'orange', 'yellow', 'green'
    out = model.move 'colors', 1, 2
    expect(out).to.eql ['orange']
    expect(model.get 'colors').to.specEql ['red', 'yellow', 'orange', 'green']
    out = model.move 'colors', 0, 3
    expect(out).to.eql ['red']
    expect(model.get 'colors').to.specEql ['yellow', 'orange', 'green', 'red']
    out = model.move 'colors', 0, 0
    expect(out).to.eql ['yellow']
    expect(model.get 'colors').to.specEql ['yellow', 'orange', 'green', 'red']

  it 'move should work on an array index path', ->
    model = new Model
    model.push 'colors', 'red', 'orange', 'yellow', 'green'
    out = model.move 'colors.1', 2
    expect(out).to.eql ['orange']
    expect(model.get 'colors').to.specEql ['red', 'yellow', 'orange', 'green']
    out = model.move 'colors.0', 3
    expect(out).to.eql ['red']
    expect(model.get 'colors').to.specEql ['yellow', 'orange', 'green', 'red']
    out = model.move 'colors.0', 0
    expect(out).to.eql ['yellow']
    expect(model.get 'colors').to.specEql ['yellow', 'orange', 'green', 'red']
