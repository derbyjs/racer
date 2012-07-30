{expect} = require './util'
Memory = require '../lib/Memory'

describe 'Memory', ->

  it 'test get and set', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    expect(memory.version).to.equal ver

    memory.set 'color', null, ++ver, null
    expect(memory.get 'color').to.equal null
    expect(memory.version).to.equal ver

    memory.set 'color', 'green', ++ver, null
    expect(memory.get 'color').to.equal 'green'
    expect(memory.version).to.equal ver

    memory.set 'info.numbers', first: 2, second: 10, ++ver, null
    expect(memory.get 'info.numbers').to.specEql {id: 'numbers', first: 2, second: 10}
    expect(memory.get()).to.specEql
        color: 'green'
        info:
          numbers:
            id: 'numbers'
            first: 2
            second: 10
    expect(memory.version).to.equal ver

    memory.set 'info', 'new', ++ver, null
    expect(memory.get()).to.specEql {color: 'green', info: 'new'}
    expect(memory.version).to.equal ver

  it 'speculative setting a nested path should not throw an error', ->
    memory = new Memory
    didErr = false
    try
      memory.set 'nested.color', 'red', null, null
    catch e
      didErr = true
    expect(didErr).to.be.false

  it 'getting an unset path should return undefined', ->
    memory = new Memory
    ver = 0
    memory.set 'info.numbers', {}, ver, null

    expect(memory.get 'color').to.equal undefined
    expect(memory.get 'color.favorite').to.equal undefined
    expect(memory.get 'info.numbers.first').to.equal undefined

  it 'test del', ->
    memory = new Memory
    ver = 0
    memory.set 'color', 'green', ver, null
    memory.set 'info.numbers', first: 2, second: 10, ver, null
    memory.del 'color', ver, null
    expect(memory.get()).to.specEql
      info:
        numbers:
          id: 'numbers'
          first: 2
          second: 10

    memory.del 'info.numbers', ver, null
    expect(memory.get()).to.specEql {info: {}}

    # Make sure deleting something that doesn't exist isn't a problem
    memory.del 'a.b.c', ++ver, null

    expect(memory.version).to.equal ver

  it 'should be able to push a single value onto an undefined path', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    memory.push 'colors', 'green', ver, null
    expect(memory.get 'colors').to.specEql ['green']

  it 'should be able to pop from a single member array path', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    memory.push 'colors', 'green', ver, null
    memory.pop 'colors', ver, null
    expect(memory.get 'colors').to.specEql []

  it 'should be able to push multiple members onto an array path', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    memory.push 'colors', 'green', ver, null
    memory.push 'colors', 'red', 'blue', 'purple', ver, null
    expect(memory.get 'colors').to.specEql ['green', 'red', 'blue', 'purple']

  it 'should be able to pop from a multiple member array path', ->
    memory = new Memory
    ver = 0
    memory.push 'colors', 'red', 'blue', 'purple', ver, null
    memory.pop 'colors', ver, null
    expect(memory.get 'colors').to.specEql ['red', 'blue']

  it 'pop on a non array should throw a "Not an Array" error', ->
    memory = new Memory
    ver = 0
    memory.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      memory.pop 'nonArray', ver, null
    catch e
      expect(e.message.toLowerCase()).to.contain 'not an array'
      didThrowNotAnArray = true
    expect(didThrowNotAnArray).to.be.true

  it 'push on a non array should throw a "Not an Array" error', ->
    memory = new Memory
    ver = 0
    memory.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      memory.push 'nonArray', 5, 6, ver, null
    catch e
      expect(e.message.toLowerCase()).to.contain 'not an array'
      didThrowNotAnArray = true
    expect(didThrowNotAnArray).to.be.true

  it 'should be able to unshift a single value onto an undefined path', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    memory.unshift 'colors', 'green', ver, null
    expect(memory.get 'colors').to.specEql ['green']

  it 'should be able to shift from a single member array path', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    memory.unshift 'colors', 'green', ver, null
    memory.shift 'colors', ver, null
    expect(memory.get 'colors').to.specEql []

  it 'should be able to unshift multiple members onto an array path', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    memory.unshift 'colors', 'red', 'blue', 'purple', ver, null
    expect(memory.get 'colors').to.specEql ['red', 'blue', 'purple']

  it 'should be able to shift from a multiple member array path', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    memory.unshift 'colors', 'red', 'blue', 'purple', ver, null
    memory.shift 'colors', ver, null
    expect(memory.get 'colors').to.specEql ['blue', 'purple']

  it 'shift on a non array should throw a "Not an Array" error', ->
    memory = new Memory
    ver = 0
    memory.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      memory.shift 'nonArray', ver, null
    catch e
      expect(e.message.toLowerCase()).to.contain 'not an array'
      didThrowNotAnArray = true
    expect(didThrowNotAnArray).to.be.true

  it 'unshift on a non array should throw a "Not an Array" error', ->
    memory = new Memory
    ver = 0
    memory.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      memory.unshift 'nonArray', 5, 6, ver, null
    catch e
      expect(e.message.toLowerCase()).to.contain 'not an array'
      didThrowNotAnArray = true
    expect(didThrowNotAnArray).to.be.true

  it 'insert 0 on an undefined path should result in a new array', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}
    memory.insert 'colors', 0, 'yellow', ver, null
    expect(memory.get 'colors').to.specEql ['yellow']

  it 'insert 0 on an empty array should fill the array with only those elements', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', [], ver, null
    memory.insert 'colors', 0, 'yellow', ver, null
    expect(memory.get 'colors').to.specEql ['yellow']

  it 'insert 0 in an array should act like a shift', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['yellow', 'black'], ver, null
    memory.insert 'colors', 0, 'violet', ver, null
    expect(memory.get 'colors').to.specEql ['violet', 'yellow', 'black']

  it 'insert the length of an array should act like a push', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['yellow', 'black'], ver, null
    memory.insert 'colors', 2, 'violet', ver, null
    expect(memory.get 'colors').to.specEql ['yellow', 'black', 'violet']

  it 'insert should be able to insert in-between an array with length >= 2', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['violet', 'yellow', 'black'], ver, null
    memory.insert 'colors', 1, 'orange', ver, null
    expect(memory.get 'colors').to.specEql ['violet', 'orange', 'yellow', 'black']

  it 'insert on a non-array should throw a "Not an Array" error', ->
    memory = new Memory
    ver = 0
    memory.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      memory.insert 'nonArray', 0, 'never added', ver, null
    catch e
      expect(e.message.toLowerCase()).to.contain 'not an array'
      didThrowNotAnArray = true
    expect(didThrowNotAnArray).to.be.true

  it 'test move of an array item to the same index', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', 1, 1, 1, ver, null
    expect(memory.get 'colors').to.specEql ['red', 'green', 'blue']

  it 'test move of an array item from a negative index to the equivalent positive index', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', -1, 2, 1, ver, null
    expect(memory.get 'colors').to.specEql ['red', 'green', 'blue']

  it 'test move of an array item from a positive index to the equivalent negative index', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', 0, -3, 1, ver, null
    expect(memory.get 'colors').to.specEql ['red', 'green', 'blue']

  it 'test move of an array item to a later index', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', 0, 2, 1, ver, null
    expect(memory.get 'colors').to.specEql ['green', 'blue', 'red']

  it 'test move of an array item to a later index, from negative', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', -3, 2, 1, ver, null
    expect(memory.get 'colors').to.specEql ['green', 'blue', 'red']

  it 'test move of an array item to a later index, to negative', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', 0, -1, 1, ver, null
    expect(memory.get 'colors').to.specEql ['green', 'blue', 'red']

  it 'test move of an array item to an earlier index', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', 2, 1, 1, ver, null
    expect(memory.get 'colors').to.specEql ['red', 'blue', 'green']

  it 'test move of an array item to an earlier index, from negative', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', -1, 1, 1, ver, null
    expect(memory.get 'colors').to.specEql ['red', 'blue', 'green']

  it 'test move of an array item to an earlier index, to negative', ->
    memory = new Memory
    ver = 0
    memory.set 'colors', ['red', 'green', 'blue'], ver, null
    memory.move 'colors', 2, -2, 1, ver, null
    expect(memory.get 'colors').to.specEql ['red', 'blue', 'green']

  it 'move on a non-array should throw a "Not an Array" error', ->
    memory = new Memory
    ver = 0
    memory.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      memory.move 'nonArray', 0, 0, 1, ver, null
    catch e
      expect(e.message.toLowerCase()).to.contain 'not an array'
      didThrowNotAnArray = true
    expect(didThrowNotAnArray).to.be.true

  it 'test remove (from array)', ->
    memory = new Memory
    ver = 0
    expect(memory.get()).to.specEql {}

    # on a defined non-array
    didThrowNotAnArray = false
    memory.set 'nonArray', '9', ver, null
    try
      memory.remove 'nonArray', 0, 3, ver, null
    catch e
      expect(e.message.toLowerCase()).to.contain 'not an array'
      didThrowNotAnArray = true
    expect(didThrowNotAnArray).to.be.true

    # on a non-empty array, with howMany to remove in-bounds
    memory.set 'colors', ['red', 'yellow', 'orange'], ver, null
    memory.remove 'colors', 0, 2, ver, null
    expect(memory.get 'colors').to.specEql ['orange']
