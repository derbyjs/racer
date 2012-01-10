should = require 'should'
require '../util'
specHelper = require '../../src/specHelper'

module.exports = (AdapterSync) ->

  'test get and set': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.version.should.equal ver

    adapterSync.set 'color', null, ++ver, null
    should.equal null, adapterSync.get('color')
    adapterSync.version.should.equal ver
    
    adapterSync.set 'color', 'green', ++ver, null
    adapterSync.get('color').should.equal 'green'
    adapterSync.version.should.equal ver
    
    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver, null
    adapterSync.get('info.numbers').should.specEql {first: 2, second: 10}
    adapterSync.get().should.specEql
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10
    adapterSync.version.should.equal ver
    
    adapterSync.set 'info', 'new', ++ver, null
    adapterSync.get().should.specEql {color: 'green', info: 'new'}
    adapterSync.version.should.equal ver

  'speculative setting a nested path should not throw an error': ->
    adapterSync = new AdapterSync
    didErr = false
    try
      adapterSync.set 'nested.color', 'red', null, null
    catch e
      didErr = true
    didErr.should.be.false

  'getting an unset path should return undefined': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'info.numbers', {}, ver, null
    
    should.equal undefined, adapterSync.get('color')
    should.equal undefined, adapterSync.get('color.favorite')
    should.equal undefined, adapterSync.get('info.numbers.first')

  'test del': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ver, null
    adapterSync.set 'info.numbers', first: 2, second: 10, ver, null
    adapterSync.del 'color', ver, null
    adapterSync.get().should.specEql
      info:
        numbers:
          first: 2
          second: 10
    
    adapterSync.del 'info.numbers', ver, null
    adapterSync.get().should.specEql {info: {}}
    
    # Make sure deleting something that doesn't exist isn't a problem
    adapterSync.del 'a.b.c', ++ver, null

    adapterSync.version.should.equal ver

  'should be able to push a single value onto an undefined path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.push 'colors', 'green', ver, null
    adapterSync.get('colors').should.specEql ['green']

  'should be able to pop from a single member array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.push 'colors', 'green', ver, null
    adapterSync.pop 'colors', ver, null
    adapterSync.get('colors').should.specEql []

  'should be able to push multiple members onto an array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.push 'colors', 'green', ver, null
    adapterSync.push 'colors', 'red', 'blue', 'purple', ver, null
    adapterSync.get('colors').should.specEql ['green', 'red', 'blue', 'purple']

  'should be able to pop from a multiple member array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'red', 'blue', 'purple', ver, null
    adapterSync.pop 'colors', ver, null
    adapterSync.get('colors').should.specEql ['red', 'blue']

  'pop on a non array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      adapterSync.pop 'nonArray', ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'push on a non array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      adapterSync.push 'nonArray', 5, 6, ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true


  'should be able to unshift a single value onto an undefined path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.unshift 'colors', 'green', ver, null
    adapterSync.get('colors').should.specEql ['green']

  'should be able to shift from a single member array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.unshift 'colors', 'green', ver, null
    adapterSync.shift 'colors', ver, null
    adapterSync.get('colors').should.specEql []

  'should be able to unshift multiple members onto an array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.unshift 'colors', 'red', 'blue', 'purple', ver, null
    adapterSync.get('colors').should.specEql ['red', 'blue', 'purple']

  'should be able to shift from a multiple member array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.unshift 'colors', 'red', 'blue', 'purple', ver, null
    adapterSync.shift 'colors', ver, null
    adapterSync.get('colors').should.specEql ['blue', 'purple']

  'shift on a non array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      adapterSync.shift 'nonArray', ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'unshift on a non array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      adapterSync.unshift 'nonArray', 5, 6, ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true


  'insertAfter -1 on an undefined path should result in a new array': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.insertAfter 'colors', -1, 'yellow', ver, null
    adapterSync.get('colors').should.specEql ['yellow']

  'insertAfter -1 on an empty array should fill the array with only those elements': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', [], ver, null
    adapterSync.insertAfter 'colors', -1, 'yellow', ver, null
    adapterSync.get('colors').should.specEql ['yellow']

  'insertAfter the length-1 of an array should act like a push on the array': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow'], ver, null
    adapterSync.insertAfter 'colors', 0, 'black', ver, null
    adapterSync.get('colors').should.specEql ['yellow', 'black']

  'insertAfter should be able to insert in-between an array with length >= 2': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ver, null
    adapterSync.insertAfter 'colors', 0, 'violet', ver, null
    adapterSync.get('colors').should.specEql ['yellow', 'violet', 'black']

  'insertAfter == length should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertAfter 'colors', 2, 'violet', ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertAfter > length should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertAfter 'colors', 100, 'violet', ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertAfter < -1 should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertAfter 'colors', -2, 'violet', ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertAfter on a non-array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ver, null
    try
      adapterSync.insertAfter 'nonArray', -1, 'never added', ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true


  'insertBefore 0 on an undefined path should result in a new array': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}
    adapterSync.insertBefore 'colors', 0, 'yellow', ver, null
    adapterSync.get('colors').should.specEql ['yellow']

  'insertBefore 0 on an empty array should fill the array with only those elements': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', [], ver, null
    adapterSync.insertBefore 'colors', 0, 'yellow', ver, null
    adapterSync.get('colors').should.specEql ['yellow']

  'insertBefore 0 in an array should act like a shift': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ver, null
    adapterSync.insertBefore 'colors', 0, 'violet', ver, null
    adapterSync.get('colors').should.specEql ['violet', 'yellow', 'black']

  'insertBefore the length of an array should act like a push': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ver, null
    adapterSync.insertBefore 'colors', 2, 'violet', ver, null
    adapterSync.get('colors').should.specEql ['yellow', 'black', 'violet']

  'insertBefore should be able to insert in-between an array with length >= 2': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['violet', 'yellow', 'black'], ver, null
    adapterSync.insertBefore 'colors', 1, 'orange', ver, null
    adapterSync.get('colors').should.specEql ['violet', 'orange', 'yellow', 'black']

  'insertBefore -1 should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertBefore 'colors', -1, 'violet', ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertBefore == length+1 should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertBefore 'colors', 2, 'violet', ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertBefore > length+1 should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertBefore 'colors', 3, 'violet', ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertBefore on a non-array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      adapterSync.insertBefore 'nonArray', 0, 'never added', ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true


  'test move of an array item to the same index': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', 1, 1, ver, null
    adapterSync.get('colors').should.specEql ['red', 'green', 'blue']
  
  'test move of an array item from a negative index to the equivalent positive index': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', -1, 2, ver, null
    adapterSync.get('colors').should.specEql ['red', 'green', 'blue']

  'test move of an array item from a positive index to the equivalent negative index': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', 0, -3, ver, null
    adapterSync.get('colors').should.specEql ['red', 'green', 'blue']

  'test move of an array item to a later index': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', 0, 2, ver, null
    adapterSync.get('colors').should.specEql ['green', 'blue', 'red']

  'test move of an array item to a later index, from negative': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', -3, 2, ver, null
    adapterSync.get('colors').should.specEql ['green', 'blue', 'red']

  'test move of an array item to a later index, to negative': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', 0, -1, ver, null
    adapterSync.get('colors').should.specEql ['green', 'blue', 'red']

  'test move of an array item to an earlier index': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', 2, 1, ver, null
    adapterSync.get('colors').should.specEql ['red', 'blue', 'green']

  'test move of an array item to an earlier index, from negative': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', -1, 1, ver, null
    adapterSync.get('colors').should.specEql ['red', 'blue', 'green']
  
  'test move of an array item to an earlier index, to negative': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'green', 'blue'], ver, null
    adapterSync.move 'colors', 2, -2, ver, null
    adapterSync.get('colors').should.specEql ['red', 'blue', 'green']

  'move from > max index should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'purple'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.move 'colors', 2, 0, ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true
  
  'move from <= -len should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'purple'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.move 'colors', -3, 0, ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true
  
  'move to > max index should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'purple'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.move 'colors', 0, 2, ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true
  
  'move to <= -len should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'purple'], ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.move 'colors', 0, -3, ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'move on a non-array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ver, null
    didThrowNotAnArray = false
    try
      adapterSync.move 'nonArray', 0, 0, ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true


  'test remove (from array)': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}

    # on a defined non-array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ver, null
    try
      adapterSync.remove 'nonArray', 0, 3, ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

    # on an empty array
    adapterSync.set 'colors', [], ver, null
    adapterSync.remove 'colors', 0, 3, ver, null
    adapterSync.get('colors').should.specEql []
    
    # on a non-empty array, with howMany to remove in-bounds
    adapterSync.push 'colors', 'red', 'yellow', 'orange', ver, null
    adapterSync.remove 'colors', 0, 2, ver, null
    adapterSync.get('colors').should.specEql ['orange']

    # on a non-empty array, with howMany to remove out of bounds
    adapterSync.remove 'colors', 0, 2, ver, null
    adapterSync.get('colors').should.specEql []

    # on a non-empty array, with startAt index out-of-bounds
    adapterSync.push 'colors', 'blue', 'green', 'pink', ver, null
    adapterSync.get('colors').should.specEql ['blue', 'green', 'pink']
    didThrowOutOfBounds = false
    try
      adapterSync.remove 'colors', -1, 1, ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true
    didThrowOutOfBounds = false
    try
      adapterSync.remove 'colors', 3, 1, ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true


  'test splice': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.specEql {}

    # on undefined
    adapterSync.splice 'undefined', 0, 3, 1, 2, ver, null
    adapterSync.get('undefined').should.specEql [1, 2]

    # on a defined non-array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ver, null
    try
      adapterSync.remove 'nonArray', 0, 3, ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

    # on an empty array
    adapterSync.set 'colors', [], ver, null
    adapterSync.splice 'colors', 0, 0, 'red', 'orange', 'yellow', 'green', 'blue', 'violet', ver, null
    adapterSync.get('colors').should.specEql ['red', 'orange', 'yellow', 'green', 'blue', 'violet']
    
    # on a non-empty array
    adapterSync.splice 'colors', 2, 3, 'pink', 'gray', ver, null
    adapterSync.get('colors').should.specEql ['red', 'orange', 'pink', 'gray', 'violet']

    # like push
    adapterSync.splice 'colors', 5, 0, 'peach', ver, null
    adapterSync.get('colors').should.specEql ['red', 'orange', 'pink', 'gray', 'violet', 'peach']

    # like pop
    adapterSync.splice 'colors', 5, 1, ver, null
    adapterSync.get('colors').should.specEql ['red', 'orange', 'pink', 'gray', 'violet']

    # like remove
    adapterSync.splice 'colors', 1, 2, ver, null
    adapterSync.get('colors').should.specEql ['red', 'gray', 'violet']

    # like shift
    adapterSync.splice 'colors', 0, 1, ver, null
    adapterSync.get('colors').should.specEql ['gray', 'violet']

    # with an out-of-bounds index
    adapterSync.splice 'colors', 100, 50, 'blue', ver, null
    adapterSync.get('colors').should.specEql ['gray', 'violet', 'blue']
