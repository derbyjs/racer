should = require 'should'
require '../util'

module.exports = (AdapterSync) ->

  'test get and set': ->
    adapterSync = new AdapterSync
    adapterSync.get().should.eql {}
    
    adapterSync.set 'color', 'green'
    adapterSync.get('color').should.eql 'green'
    
    adapterSync.set 'info.numbers', first: 2, second: 10
    adapterSync.get('info.numbers').should.eql first: 2, second: 10
    adapterSync.get().should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    adapterSync.set 'info', 'new'
    adapterSync.get().should.eql color: 'green', info: 'new'
  
  'getting an unset path should return undefined': ->
    adapterSync = new AdapterSync
    adapterSync.set 'info.numbers', {}
    
    should.equal undefined, adapterSync.get 'color'
    should.equal undefined, adapterSync.get 'color.favorite'
    should.equal undefined, adapterSync.get 'info.numbers.first'

  'test del': ->
    adapterSync = new AdapterSync
    adapterSync.set 'color', 'green'
    adapterSync.set 'info.numbers', first: 2, second: 10
    
    adapterSync.del 'color'
    adapterSync.get().should.eql
      info:
        numbers:
          first: 2
          second: 10
    
    adapterSync.del 'info.numbers'
    adapterSync.get().should.eql info: {}

  'test push and pop': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {}
    
    adapterSync.push 'colors', 'green', ++ver
    adapterSync.get('colors').should.eql ['green']

    adapterSync.pop 'colors', ++ver
    adapterSync.get('colors').should.eql []
    adapterSync.push 'colors', 'red', 'blue', 'purple', ++ver
    adapterSync.get('colors').should.eql ['red', 'blue', 'purple']
    adapterSync.pop 'colors', ++ver
    adapterSync.get('colors').should.eql ['red', 'blue']
    adapterSync.push 'colors', 'orange', ++ver
    adapterSync.get('colors').should.eql ['red', 'blue', 'orange']

  'test insertAfter': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {}

    # on undefined
    adapterSync.insertAfter 'colors', -1, 'yellow', ++ver
    adapterSync.get('colors').should.eql ['yellow']

    # on an empty array
    adapterSync.pop 'colors', ++ver
    adapterSync.get('colors').should.eql []
    adapterSync.insertAfter 'colors', -1, 'yellow', ++ver
    adapterSync.get('colors').should.eql ['yellow']

    # insertAfter like push
    adapterSync.insertAfter 'colors', 0, 'black', ++ver

    # in-between an array with length >= 2
    adapterSync.get('colors').should.eql ['yellow', 'black']
    adapterSync.insertAfter 'colors', 0, 'violet', ++ver
    adapterSync.get('colors').should.eql ['yellow', 'violet', 'black']

    # out of bounds
    didThrowOutOfBounds = false
    try
      adapterSync.insertAfter 'colors', 100, 'violet', ++ver
    catch e
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

    # not on an array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver
    try
      adapterSync.insertAfter 'nonArray', -1, 'never added', ++ver
    catch e
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'test insertBefore': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {}

    # on undefined
    adapterSync.insertBefore 'colors', 0, 'yellow', ++ver
    adapterSync.get('colors').should.eql ['yellow']

    # on an empty array
    adapterSync.pop 'colors', ++ver
    adapterSync.get('colors').should.eql []
    adapterSync.insertBefore 'colors', 0, 'yellow', ++ver
    adapterSync.get('colors').should.eql ['yellow']
    
    # like shift
    adapterSync.insertBefore 'colors', 0, 'violet', ++ver
    adapterSync.get('colors').should.eql ['violet', 'yellow']

    # like push
    adapterSync.insertBefore 'colors', 2, 'black', ++ver
    adapterSync.get('colors').should.eql ['violet', 'yellow', 'black']
    
    # in-between an array with length >= 2
    adapterSync.insertBefore 'colors', 1, 'orange', ++ver
    adapterSync.get('colors').should.eql ['violet', 'orange', 'yellow', 'black']

    # out of bounds
    didThrowOutOfBounds = false
    try
      adapterSync.insertBefore 'colors', 100, 'violet', ++ver
    catch e
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

    # not an array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver
    try
      adapterSync.insertBefore 'nonArray', 0, 'never added', ++ver
    catch e
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true
