should = require 'should'
require '../util'

module.exports = (AdapterSync) ->

  'test get and set': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql { val: {}, ver }
    
    adapterSync.set 'color', 'green', ++ver
    adapterSync.get('color').should.eql { val: 'green', ver }
    
    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver
    adapterSync.get('info.numbers').should.eql { val: {first: 2, second: 10}, ver}
    adapterSync.get().should.eql
      val:
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10
      ver: ver
    
    adapterSync.set 'info', 'new', ++ver
    adapterSync.get().should.eql { val: {color: 'green', info: 'new'}, ver}

  'setting a path to a ver should update the path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver
    adapterSync.version('color').should.equal ver

  '''setting a path to an object and fetching the
  version of that object should return the same
  version of the parent object''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: {} }, ++ver
    adapterSync.version('favorites').should.equal ver
    adapterSync.version('favorites.colors').should.equal ver

  '''setting a path to an object and later updating a
  property of that object should set the version of
  that object''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: {} }, ++ver
    adapterSync.set 'favorites.colors.first', 'green', ++ver
    adapterSync.version('favorites.colors').should.equal ver
  
  'setting a path to a ver should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.version().should.equal ver
    adapterSync.set 'color', 'green', ++ver
    adapterSync.version().should.equal ver

  'setting a chained path to a ver should update all subpath vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.version().should.equal ver
    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver
    adapterSync.version('info.numbers').should.equal ver
    adapterSync.version('info').should.equal ver
    adapterSync.version().should.equal ver

  'setting a path to a ver should not update a sibling path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver

    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver
    # TODO Hmmm, how do we treat versions when we get to eg mongodb?
    adapterSync.version('color').should.equal ver-1
  
  'getting an unset path should return undefined': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'info.numbers', {}, ++ver
    
    adapterSync.get('color').should.eql {val: undefined, ver}
    adapterSync.get('color.favorite').should.eql {val: undefined, ver}
    adapterSync.get('info.numbers.first').should.eql {val: undefined, ver}

  'test del': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver
    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver
    adapterSync.del 'color', ++ver
    adapterSync.get().should.eql
      val:
        info:
          numbers:
            first: 2
            second: 10
      ver: ver
    
    adapterSync.del 'info.numbers', ++ver
    adapterSync.get().should.eql {val: {info: {}}, ver}
    
    # Make sure deleting something that doesn't exist isn't a problem
    adapterSync.del 'a.b.c', ++ver

  'deleting a path using a ver should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver
    adapterSync.del 'color', ++ver
    adapterSync.version().should.equal ver

  'deleting a path using a ver should update all subpath vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors.first', 'green', ++ver
    adapterSync.set 'colors.second', 'red', ++ver
    adapterSync.del 'colors.first', ++ver
    adapterSync.version('colors').should.equal ver
    adapterSync.version().should.equal ver

  'deleting a path using a ver should not update a sibling path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors.first', 'green', ++ver
    adapterSync.set 'colors.second', 'red', ++ver
    adapterSync.del 'colors.first', ++ver
    adapterSync.version('colors.second').should.equal ver-1

  'test push and pop': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {val: {}, ver}
    
    adapterSync.push 'colors', 'green', ++ver
    adapterSync.get('colors').should.eql {val: ['green'], ver}

    adapterSync.pop 'colors', ++ver
    adapterSync.get('colors').should.eql {val: [], ver}
    adapterSync.push 'colors', 'red', 'blue', 'purple', ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'blue', 'purple'], ver}
    adapterSync.pop 'colors', ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'blue'], ver}
    adapterSync.push 'colors', 'orange', ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'blue', 'orange'], ver}

    adapterSync.set 'nonArray', '9', ++ver
    didThrowNotAnArray = false
    try
      adapterSync.pop 'nonArray', ++ver
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true
    
    didThrowNotAnArray = false
    try
      adapterSync.push 'nonArray', 5, 6, ++ver
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  '''pushing a member onto a path + specifying a version should
  set the path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'green', ++ver
    adapterSync.version('colors').should.equal ver

  '''pushing a member onto a path + specifying a version should
  update the root ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.version().should.equal ver
    adapterSync.push 'colors', 'green', ++ver
    adapterSync.version().should.equal ver

  '''pushing a member onto a path + specifying a version should
  update all subpath vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: [] }, ++ver
    adapterSync.version('favorites').should.equal ver
    adapterSync.push 'favorites.colors', 'green', ++ver
    adapterSync.version('favorites').should.equal ver
    adapterSync.version().should.equal ver

  '''pushing a member onto a path + specifying a version should
  not update a sibling path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: [] }, ++ver
    adapterSync.set 'favorites.day', 'saturday', ++ver
    adapterSync.version('favorites.day').should.equal ver
    adapterSync.push 'favorites.colors', 'green', ++ver
    adapterSync.version('favorites.colors').should.equal ver
    adapterSync.version('favorites.day').should.equal ver-1

  '''popping a path + specifying a version should update 
  the path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'red', 'green', 'blue', ++ver
    adapterSync.pop 'colors', ++ver
    adapterSync.version('colors').should.equal ver

  '''popping a path + specifying a version should update
  the root ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'red', 'green', 'blue', ++ver
    adapterSync.pop 'colors', ++ver
    adapterSync.version().should.equal ver

  '''popping a nested path + specifying a version should
  update all subpath vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors.favs', 'red', 'green', 'blue', ++ver
    adapterSync.pop 'colors.favs', ++ver
    adapterSync.version('colors.favs').should.equal ver
    adapterSync.version('colors').should.equal ver

  '''popping a path + specifying a version should
  not update a sibling path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors.favs', 'red', 'green', 'blue', ++ver
    adapterSync.push 'colors.blacklist', 'orange', ++ver
    adapterSync.pop 'colors.favs', ++ver
    adapterSync.version('colors.blacklist').should.equal ver-1

  'test shift and unshift': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {val: {}, ver}
    
    adapterSync.unshift 'colors', 'green', ++ver
    adapterSync.get('colors').should.eql {val: ['green'], ver}

    adapterSync.shift 'colors', ++ver
    adapterSync.get('colors').should.eql {val: [], ver}
    adapterSync.unshift 'colors', 'red', 'blue', 'purple', ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'blue', 'purple'], ver}
    adapterSync.shift 'colors', ++ver
    adapterSync.get('colors').should.eql {val: ['blue', 'purple'], ver}
    adapterSync.unshift 'colors', 'orange', ++ver
    adapterSync.get('colors').should.eql {val: ['orange', 'blue', 'purple'], ver}

    adapterSync.set 'nonArray', '9', ++ver
    didThrowNotAnArray = false
    try
      adapterSync.shift 'nonArray', ++ver
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true
    
    didThrowNotAnArray = false
    try
      adapterSync.unshift 'nonArray', 5, 6, ++ver
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'test insertAfter': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {val: {}, ver}

    # on undefined
    adapterSync.insertAfter 'colors', -1, 'yellow', ++ver
    adapterSync.get('colors').should.eql {val: ['yellow'], ver}

    # on an empty array
    adapterSync.pop 'colors', ++ver
    adapterSync.get('colors').should.eql {val: [], ver}
    adapterSync.insertAfter 'colors', -1, 'yellow', ++ver
    adapterSync.get('colors').should.eql {val: ['yellow'], ver}

    # insertAfter like push
    adapterSync.insertAfter 'colors', 0, 'black', ++ver

    # in-between an array with length >= 2
    adapterSync.get('colors').should.eql {val: ['yellow', 'black'], ver}
    adapterSync.insertAfter 'colors', 0, 'violet', ++ver
    adapterSync.get('colors').should.eql {val: ['yellow', 'violet', 'black'], ver}

    # out of bounds
    didThrowOutOfBounds = false
    try
      adapterSync.insertAfter 'colors', 100, 'violet', ++ver
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

    # not on an array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver
    try
      adapterSync.insertAfter 'nonArray', -1, 'never added', ++ver
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'test insertBefore': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {val: {}, ver}

    # on undefined
    adapterSync.insertBefore 'colors', 0, 'yellow', ++ver
    adapterSync.get('colors').should.eql {val: ['yellow'], ver}

    # on an empty array
    adapterSync.pop 'colors', ++ver
    adapterSync.get('colors').should.eql {val: [], ver}
    adapterSync.insertBefore 'colors', 0, 'yellow', ++ver
    adapterSync.get('colors').should.eql {val: ['yellow'], ver}
    
    # like shift
    adapterSync.insertBefore 'colors', 0, 'violet', ++ver
    adapterSync.get('colors').should.eql {val: ['violet', 'yellow'], ver}

    # like push
    adapterSync.insertBefore 'colors', 2, 'black', ++ver
    adapterSync.get('colors').should.eql {val: ['violet', 'yellow', 'black'], ver}
    
    # in-between an array with length >= 2
    adapterSync.insertBefore 'colors', 1, 'orange', ++ver
    adapterSync.get('colors').should.eql {val: ['violet', 'orange', 'yellow', 'black'], ver}

    # out of bounds
    didThrowOutOfBounds = false
    try
      adapterSync.insertBefore 'colors', 100, 'violet', ++ver
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

    # not an array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver
    try
      adapterSync.insertBefore 'nonArray', 0, 'never added', ++ver
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'test remove (from array)': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {val: {}, ver}

#    # on undefined
#    didThrowNotAnArray = false
#    try
#      adapterSync.remove 'undefined', 0, 3, ++ver
#    catch e
#      e.message.should.equal 'Not an Array'
#      didThrowNotAnArray = true
#    didThrowNotAnArray.should.be.true

    # on a defined non-array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver
    try
      adapterSync.remove 'nonArray', 0, 3, ++ver
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

    # on an empty array
    adapterSync.set 'colors', [], ++ver
    adapterSync.remove 'colors', 0, 3, ++ver
    adapterSync.get('colors').should.eql {val: [], ver}
    
    # on a non-empty array, with howMany to remove in-bounds
    adapterSync.push 'colors', 'red', 'yellow', 'orange', ++ver
    adapterSync.remove 'colors', 0, 2, ++ver
    adapterSync.get('colors').should.eql {val: ['orange'], ver}

    # on a non-empty array, with howMany to remove out of bounds
    adapterSync.remove 'colors', 0, 2, ++ver
    adapterSync.get('colors').should.eql {val: [], ver}

    # on a non-empty array, with startAt index out-of-bounds
    adapterSync.push 'colors', 'blue', 'green', 'pink', ++ver
    adapterSync.get('colors').should.eql {val: ['blue', 'green', 'pink'], ver}
    didThrowOutOfBounds = false
    try
      adapterSync.remove 'colors', -1, 1, ++ver
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true
    didThrowOutOfBounds = false
    try
      adapterSync.remove 'colors', 3, 1, ++ver
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'test splice': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.get().should.eql {val: {}, ver}

    # on undefined
    adapterSync.splice 'undefined', 0, 3, 1, 2, ++ver
    adapterSync.get('undefined').should.eql {val: [1, 2], ver}

    # on a defined non-array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver
    try
      adapterSync.remove 'nonArray', 0, 3, ++ver
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

    # on an empty array
    adapterSync.set 'colors', [], ++ver
    adapterSync.splice 'colors', 0, 0, 'red', 'orange', 'yellow', 'green', 'blue', 'violet', ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'orange', 'yellow', 'green', 'blue', 'violet'], ver}
    
    # on a non-empty array
    adapterSync.splice 'colors', 2, 3, 'pink', 'gray', ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'orange', 'pink', 'gray', 'violet'], ver}

    # like push
    adapterSync.splice 'colors', 5, 0, 'peach', ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'orange', 'pink', 'gray', 'violet', 'peach'], ver}

    # like pop
    adapterSync.splice 'colors', 5, 1, ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'orange', 'pink', 'gray', 'violet'], ver}

    # like remove
    adapterSync.splice 'colors', 1, 2, ++ver
    adapterSync.get('colors').should.eql {val: ['red', 'gray', 'violet'], ver}

    # like shift
    adapterSync.splice 'colors', 0, 1, ++ver
    adapterSync.get('colors').should.eql {val: ['gray', 'violet'], ver}

    # with an out-of-bounds index
    adapterSync.splice 'colors', 100, 50, 'blue', ++ver
    adapterSync.get('colors').should.eql {val: ['gray', 'violet', 'blue'], ver}
