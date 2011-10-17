should = require 'should'
require '../util'
specHelper = require '../../src/specHelper'

module.exports = (AdapterSync) ->

  'test get and set': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]

    adapterSync.set 'color', null, ++ver, null
    adapterSync.getWithVersion('color').should.specEql [null, ver]
    
    adapterSync.set 'color', 'green', ++ver, null
    adapterSync.getWithVersion('color').should.specEql ['green', ver]
    
    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver, null
    adapterSync.getWithVersion('info.numbers').should.specEql [{first: 2, second: 10}, ver]
    adapterSync.getWithVersion().should.specEql [
        color: 'green'
        info:
          numbers:
            first: 2
            second: 10
      , ver
    ]
    
    adapterSync.set 'info', 'new', ++ver, null
    adapterSync.getWithVersion().should.specEql [{color: 'green', info: 'new'}, ver]

  'setting a path to a ver should update the path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver, null
    adapterSync.version('color').should.equal ver

  '''setting a path to an object and fetching the
  version of that object should return the same
  version of the parent object''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: {} }, ++ver, null
    adapterSync.version('favorites').should.equal ver
    adapterSync.version('favorites.colors').should.equal ver

  '''setting a path to an object and later updating a
  property of that object should set the version of
  that object''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: {} }, ++ver, null
    adapterSync.set 'favorites.colors.first', 'green', ++ver, null
    adapterSync.version('favorites.colors').should.equal ver
  
  'setting a path to a ver should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.version().should.equal ver
    adapterSync.set 'color', 'green', ++ver, null
    adapterSync.version().should.equal ver

  'setting a chained path to a ver should update all subpath vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.version().should.equal ver
    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver, null
    adapterSync.version('info.numbers').should.equal ver
    adapterSync.version('info').should.equal ver
    adapterSync.version().should.equal ver

  'setting a path to a ver should not update a sibling path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver, null

    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver, null
    # TODO Hmmm, how do we treat versions when we get to eg mongodb?
    adapterSync.version('color').should.equal ver-1

  '''speculative setting a path without specifying a version
  should not modify versions''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver, null
    adapterSync.set 'color', 'red', null, null
    adapterSync.version('color').should.equal ver

  'speculative setting a nested path should not throw an error': ->
    adapterSync = new AdapterSync
    didErr = false
    try
      adapterSync.set 'nested.color', 'red', null, null
    catch e
      didErr = true
    didErr.should.be.false

  'lookup of a speculative ref should not err': ->
    # TODO: Don't use internal adapter details
    adapterSync = new AdapterSync
    adapterSync.set 'color', {$r: 'colors.green'}, null, data = specHelper.create(adapterSync._data)
    didErr = false
    try
      adapterSync.getRef 'color', data
    catch e
      didErr = true
    didErr.should.be.false
  
  'getting an unset path should return undefined': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'info.numbers', {}, ++ver, null
    
    adapterSync.getWithVersion('color').should.specEql [undefined, ver]
    adapterSync.getWithVersion('color.favorite').should.specEql [undefined, ver]
    adapterSync.getWithVersion('info.numbers.first').should.specEql [undefined, ver]

  'test del': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver, null
    adapterSync.set 'info.numbers', first: 2, second: 10, ++ver, null
    adapterSync.del 'color', ++ver, null
    adapterSync.getWithVersion().should.specEql [
        info:
          numbers:
            first: 2
            second: 10
      , ver
    ]
    
    adapterSync.del 'info.numbers', ++ver, null
    adapterSync.getWithVersion().should.specEql [{info: {}}, ver]
    
    # Make sure deleting something that doesn't exist isn't a problem
    adapterSync.del 'a.b.c', ++ver, null

  'deleting a path using a ver should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'green', ++ver, null
    adapterSync.del 'color', ++ver, null
    adapterSync.version().should.equal ver

  'deleting a path using a ver should update all subpath vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors.first', 'green', ++ver, null
    adapterSync.set 'colors.second', 'red', ++ver, null
    adapterSync.del 'colors.first', ++ver, null
    adapterSync.version('colors').should.equal ver
    adapterSync.version().should.equal ver

  'deleting a path using a ver should not update a sibling path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors.first', 'green', ++ver, null
    adapterSync.set 'colors.second', 'red', ++ver, null
    adapterSync.del 'colors.first', ++ver, null
    adapterSync.version('colors.second').should.equal ver-1

  'should be able to push a single value onto an undefined path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.push 'colors', 'green', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['green'], ver]

  'should be able to pop from a single member array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.push 'colors', 'green', ++ver, null
    adapterSync.pop 'colors', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [[], ver]

  'should be able to push multiple members onto an array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.push 'colors', 'green', ++ver, null
    adapterSync.push 'colors', 'red', 'blue', 'purple', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['green', 'red', 'blue', 'purple'], ver]

  'should be able to pop from a multiple member array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'red', 'blue', 'purple', ++ver, null
    adapterSync.pop 'colors', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['red', 'blue'], ver]

  'pop on a non array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ++ver, null
    didThrowNotAnArray = false
    try
      adapterSync.pop 'nonArray', ++ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'push on a non array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ++ver, null
    didThrowNotAnArray = false
    try
      adapterSync.push 'nonArray', 5, 6, ++ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  '''pushing a member onto a path + specifying a version should
  set the path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'green', ++ver, null
    adapterSync.version('colors').should.equal ver

  '''pushing a member onto a path + specifying a version should
  update the root ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.version().should.equal ver
    adapterSync.push 'colors', 'green', ++ver, null
    adapterSync.version().should.equal ver

  '''pushing a member onto a path + specifying a version should
  update all subpath vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: [] }, ++ver, null
    adapterSync.version('favorites').should.equal ver
    adapterSync.push 'favorites.colors', 'green', ++ver, null
    adapterSync.version('favorites').should.equal ver
    adapterSync.version().should.equal ver

  '''pushing a member onto a path + specifying a version should
  not update a sibling path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: [] }, ++ver, null
    adapterSync.set 'favorites.day', 'saturday', ++ver, null
    adapterSync.version('favorites.day').should.equal ver
    adapterSync.push 'favorites.colors', 'green', ++ver, null
    adapterSync.version('favorites.colors').should.equal ver
    adapterSync.version('favorites.day').should.equal ver-1

  '''popping a path + specifying a version should update 
  the path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'red', 'green', 'blue', ++ver, null
    adapterSync.pop 'colors', ++ver, null
    adapterSync.version('colors').should.equal ver

  '''popping a path + specifying a version should update
  the root ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'red', 'green', 'blue', ++ver, null
    adapterSync.pop 'colors', ++ver, null
    adapterSync.version().should.equal ver

  '''popping a nested path + specifying a version should
  update all subpath vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors.favs', 'red', 'green', 'blue', ++ver, null
    adapterSync.pop 'colors.favs', ++ver, null
    adapterSync.version('colors.favs').should.equal ver
    adapterSync.version('colors').should.equal ver

  '''popping a path + specifying a version should
  not update a sibling path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors.favs', 'red', 'green', 'blue', ++ver, null
    adapterSync.push 'colors.blacklist', 'orange', ++ver, null
    adapterSync.pop 'colors.favs', ++ver, null
    adapterSync.version('colors.blacklist').should.equal ver-1

  'should be able to unshift a single value onto an undefined path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.unshift 'colors', 'green', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['green'], ver]

  'should be able to shift from a single member array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.unshift 'colors', 'green', ++ver, null
    adapterSync.shift 'colors', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [[], ver]

  'should be able to unshift multiple members onto an array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.unshift 'colors', 'red', 'blue', 'purple', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['red', 'blue', 'purple'], ver]

  'should be able to shift from a multiple member array path': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.unshift 'colors', 'red', 'blue', 'purple', ++ver, null
    adapterSync.shift 'colors', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['blue', 'purple'], ver]

  'shift on a non array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ++ver, null
    didThrowNotAnArray = false
    try
      adapterSync.shift 'nonArray', ++ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'unshift on a non array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ++ver, null
    didThrowNotAnArray = false
    try
      adapterSync.unshift 'nonArray', 5, 6, ++ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  '''unshifting a member onto a path + specifying a version should
  set the path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.unshift 'colors', 'green', ++ver, null
    adapterSync.version('colors').should.equal ver

  '''unshifting a member onto a path + specifying a version should
  update the root ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.version().should.equal ver
    adapterSync.unshift 'colors', 'green', ++ver, null
    adapterSync.version().should.equal ver

  '''unshifting a member onto a path + specifying a version should
  update all subpath vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: [] }, ++ver, null
    adapterSync.version('favorites').should.equal ver
    adapterSync.unshift 'favorites.colors', 'green', ++ver, null
    adapterSync.version('favorites').should.equal ver
    adapterSync.version().should.equal ver

  '''unshifting a member onto a path + specifying a version should
  not update a sibling path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'favorites', { colors: [] }, ++ver, null
    adapterSync.set 'favorites.day', 'saturday', ++ver, null
    adapterSync.version('favorites.day').should.equal ver
    adapterSync.unshift 'favorites.colors', 'green', ++ver, null
    adapterSync.version('favorites.colors').should.equal ver
    adapterSync.version('favorites.day').should.equal ver-1

  '''shifting a path + specifying a version should update 
  the path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'red', 'green', 'blue', ++ver, null
    adapterSync.shift 'colors', ++ver, null
    adapterSync.version('colors').should.equal ver

  '''shifting a path + specifying a version should update
  the root ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors', 'red', 'green', 'blue', ++ver, null
    adapterSync.shift 'colors', ++ver, null
    adapterSync.version().should.equal ver

  '''shifting a nested path + specifying a version should
  update all subpath vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors.favs', 'red', 'green', 'blue', ++ver, null
    adapterSync.shift 'colors.favs', ++ver, null
    adapterSync.version('colors.favs').should.equal ver
    adapterSync.version('colors').should.equal ver

  '''shifting a path + specifying a version should
  not update a sibling path ver''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.push 'colors.favs', 'red', 'green', 'blue', ++ver, null
    adapterSync.push 'colors.blacklist', 'orange', ++ver, null
    adapterSync.shift 'colors.favs', ++ver, null
    adapterSync.version('colors.blacklist').should.equal ver-1

  'insertAfter -1 on an undefined path should result in a new array': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.insertAfter 'colors', -1, 'yellow', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['yellow'], ver]

  '''insertAfter -1 on an empty array should fill the array with
  only those elements''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', [], ++ver, null
    adapterSync.insertAfter 'colors', -1, 'yellow', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['yellow'], ver]

  '''insertAfter the length-1 of an array should act like a push
  on the array''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow'], ++ver, null
    adapterSync.insertAfter 'colors', 0, 'black', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['yellow', 'black'], ver]

  'insertAfter should be able to insert in-between an array with length>=2': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ++ver, null
    adapterSync.insertAfter 'colors', 0, 'violet', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['yellow', 'violet', 'black'], ver]

  'insertAfter == length should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ++ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertAfter 'colors', 2, 'violet', ++ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertAfter > length should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ++ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertAfter 'colors', 100, 'violet', ++ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertAfter < -1 should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ++ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertAfter 'colors', -2, 'violet', ++ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertAfter on a non-array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver, null
    try
      adapterSync.insertAfter 'nonArray', -1, 'never added', ++ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'insertAfter on a path + specifying a version should update the path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.insertAfter 'colors', -1, 'yellow', ++ver, null
    adapterSync.version('colors').should.equal ver

  'insertAfter on a path + specifying a version should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.insertAfter 'colors', -1, 'yellow', ++ver, null
    adapterSync.version().should.equal ver

  '''insertAfter on a path + specifying a version should update all
  subpath vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.insertAfter 'colors.favs', -1, 'yellow', ++ver, null
    adapterSync.version('colors.favs').should.equal ver
    adapterSync.version('colors').should.equal ver

  '''insertAfter on a path + specifying a version should not update
  sibling path vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors.best', 'green', ++ver, null
    adapterSync.insertAfter 'colors.favs', -1, 'yellow', ++ver, null
    adapterSync.version('colors.favs').should.equal ver
    adapterSync.version('colors.best').should.equal ver-1
  

  'insertBefore 0 on an undefined path should result in a new array': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]
    adapterSync.insertBefore 'colors', 0, 'yellow', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['yellow'], ver]

  '''insertBefore 0 on an empty array should fill the array
  with only those elements''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', [], ++ver, null
    adapterSync.insertBefore 'colors', 0, 'yellow', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['yellow'], ver]

  'insertBefore 0 in an array should act like a shift': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ++ver, null
    adapterSync.insertBefore 'colors', 0, 'violet', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['violet', 'yellow', 'black'], ver]

  '''insertBefore the length of an array should act like a push''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow', 'black'], ++ver, null
    adapterSync.insertBefore 'colors', 2, 'violet', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['yellow', 'black', 'violet'], ver]

  '''insertBefore should be able to insert in-between an array with length>=2''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['violet', 'yellow', 'black'], ++ver, null
    adapterSync.insertBefore 'colors', 1, 'orange', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['violet', 'orange', 'yellow', 'black'], ver]

  'insertBefore -1 should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow'], ++ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertBefore 'colors', -1, 'violet', ++ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertBefore == length+1 should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow'], ++ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertBefore 'colors', 2, 'violet', ++ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertBefore > length+1 should throw an "Out of Bounds" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['yellow'], ++ver, null
    didThrowOutOfBounds = false
    try
      adapterSync.insertBefore 'colors', 3, 'violet', ++ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'insertBefore on a non-array should throw a "Not an Array" error': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nonArray', '9', ++ver, null
    didThrowNotAnArray = false
    try
      adapterSync.insertBefore 'nonArray', 0, 'never added', ++ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

  'insertBefore on a path + specifying a version should update the path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.insertBefore 'colors', 0, 'yellow', ++ver, null
    adapterSync.version('colors').should.equal ver

  'insertBefore on a path + specifying a version should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.insertBefore 'colors', 0, 'yellow', ++ver, null
    adapterSync.version().should.equal ver

  'insertBefore on a path + specifying a version should update all subpath vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.insertBefore 'colors.favs', 0, 'yellow', ++ver, null
    adapterSync.version('colors.favs').should.equal ver
    adapterSync.version('colors').should.equal ver

  '''insertBefore on a path + specifying a version should not update
  sibling path vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors.best', 'green', ++ver, null
    adapterSync.insertBefore 'colors.favs', 0, 'yellow', ++ver, null
    adapterSync.version('colors.favs').should.equal ver
    adapterSync.version('colors.best').should.equal ver-1

  'test remove (from array)': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]

#    # on undefined
#    didThrowNotAnArray = false
#    try
#      adapterSync.remove 'undefined', 0, 3, ++ver, null
#    catch e
#      e.message.should.equal 'Not an Array'
#      didThrowNotAnArray = true
#    didThrowNotAnArray.should.be.true

    # on a defined non-array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver, null
    try
      adapterSync.remove 'nonArray', 0, 3, ++ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

    # on an empty array
    adapterSync.set 'colors', [], ++ver, null
    adapterSync.remove 'colors', 0, 3, ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [[], ver]
    
    # on a non-empty array, with howMany to remove in-bounds
    adapterSync.push 'colors', 'red', 'yellow', 'orange', ++ver, null
    adapterSync.remove 'colors', 0, 2, ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['orange'], ver]

    # on a non-empty array, with howMany to remove out of bounds
    adapterSync.remove 'colors', 0, 2, ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [[], ver]

    # on a non-empty array, with startAt index out-of-bounds
    adapterSync.push 'colors', 'blue', 'green', 'pink', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['blue', 'green', 'pink'], ver]
    didThrowOutOfBounds = false
    try
      adapterSync.remove 'colors', -1, 1, ++ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true
    didThrowOutOfBounds = false
    try
      adapterSync.remove 'colors', 3, 1, ++ver, null
    catch e
      e.message.should.equal 'Out of Bounds'
      didThrowOutOfBounds = true
    didThrowOutOfBounds.should.be.true

  'remove on a path + specifying a version should update the path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'orange', 'yellow'], ++ver, null
    adapterSync.remove 'colors', 1, 1, ++ver, null
    adapterSync.version('colors').should.equal ver

  'remove on a path + specifying a version should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'orange', 'yellow'], ++ver, null
    adapterSync.remove 'colors', 1, 1, ++ver, null
    adapterSync.version().should.equal ver

  'remove on a path + specifying a version should update all subpath vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nested.colors', ['red', 'orange', 'yellow'], ++ver, null
    adapterSync.remove 'nested.colors', 1, 1, ++ver, null
    adapterSync.version('nested.colors').should.equal ver
    adapterSync.version('nested').should.equal ver

  'remove on a path + specifying a version should not update sibling paths': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nested.directions', ['west'], constVer = ++ver, null
    adapterSync.set 'nested.colors', ['red', 'orange', 'yellow'], ++ver, null
    adapterSync.remove 'nested.colors', 1, 1, ++ver, null
    adapterSync.version('nested.directions').should.equal constVer

  'test splice': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.getWithVersion().should.specEql [{}, ver]

    # on undefined
    adapterSync.splice 'undefined', 0, 3, 1, 2, ++ver, null
    adapterSync.getWithVersion('undefined').should.specEql [[1, 2], ver]

    # on a defined non-array
    didThrowNotAnArray = false
    adapterSync.set 'nonArray', '9', ++ver, null
    try
      adapterSync.remove 'nonArray', 0, 3, ++ver, null
    catch e
      e.message.should.equal 'Not an Array'
      didThrowNotAnArray = true
    didThrowNotAnArray.should.be.true

    # on an empty array
    adapterSync.set 'colors', [], ++ver, null
    adapterSync.splice 'colors', 0, 0, 'red', 'orange', 'yellow', 'green', 'blue', 'violet', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['red', 'orange', 'yellow', 'green', 'blue', 'violet'], ver]
    
    # on a non-empty array
    adapterSync.splice 'colors', 2, 3, 'pink', 'gray', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['red', 'orange', 'pink', 'gray', 'violet'], ver]

    # like push
    adapterSync.splice 'colors', 5, 0, 'peach', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['red', 'orange', 'pink', 'gray', 'violet', 'peach'], ver]

    # like pop
    adapterSync.splice 'colors', 5, 1, ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['red', 'orange', 'pink', 'gray', 'violet'], ver]

    # like remove
    adapterSync.splice 'colors', 1, 2, ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['red', 'gray', 'violet'], ver]

    # like shift
    adapterSync.splice 'colors', 0, 1, ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['gray', 'violet'], ver]

    # with an out-of-bounds index
    adapterSync.splice 'colors', 100, 50, 'blue', ++ver, null
    adapterSync.getWithVersion('colors').should.specEql [['gray', 'violet', 'blue'], ver]

  'splice on a path + specifying a version should update the path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'orange', 'yellow'], ++ver, null
    adapterSync.splice 'colors', 1, 2, 'green', ++ver, null
    adapterSync.version('colors').should.equal ver

  'splice on a path + specifying a version should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'colors', ['red', 'orange', 'yellow'], ++ver, null
    adapterSync.splice 'colors', 1, 2, 'green', ++ver, null
    adapterSync.version().should.equal ver

  'splice on a path + specifying a version should update all subpath vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nested.colors', ['red', 'orange', 'yellow'], ++ver, null
    adapterSync.splice 'nested.colors', 1, 2, 'green', ++ver, null
    adapterSync.version('nested.colors').should.equal ver
    adapterSync.version('nested').should.equal ver

  'splice on a path + specifying a version should not update sibling vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'nested.directions', ['west'], constVer = ++ver, null
    adapterSync.set 'nested.colors', ['red', 'orange', 'yellow'], ++ver, null
    adapterSync.splice 'nested.colors', 1, 2, 'green', ++ver, null
    adapterSync.version('nested.colors').should.equal ver
    adapterSync.version('nested.directions').should.equal constVer

  # Ref Path Versioning
  'setting a path that contains a ref should update the path ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'accounts.1', { name: 'ogilvy' }, ++ver, null
    adapterSync.set 'users.1.account', {$r: 'accounts.1'}, ++ver, null
    adapterSync.set 'users.1.account.name', 'bbdo', ++ver, null
    adapterSync.version('users.1.account.name').should.equal ver

  'setting a path that contains a ref should update the root ver': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'accounts.1', { name: 'ogilvy' }, ++ver, null
    adapterSync.set 'users.1.account', {$r: 'accounts.1'}, ++ver, null
    adapterSync.set 'users.1.account.name', 'bbdo', ++ver, null
    adapterSync.version().should.equal ver

  'setting a path that contains a ref should update all subpath vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'accounts.1', { name: 'ogilvy' }, ++ver, null
    adapterSync.set 'users.1.account', {$r: 'accounts.1'}, ++ver, null
    adapterSync.set 'users.1.account.name', 'bbdo', ++ver, null
    adapterSync.version('users.1.account.name').should.equal ver
    adapterSync.version('users.1.account').should.equal ver
    adapterSync.version('users.1').should.equal ver
    adapterSync.version('users').should.equal ver

  'setting a path that contains a ref should not update sibling path vers': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'accounts.1', { name: 'ogilvy' }, ++ver, null
    adapterSync.set 'users.1.account', {$r: 'accounts.1'}, ++ver, null
    adapterSync.set 'users.1.name', 'skynet', constVer = ++ver, null
    adapterSync.set 'users.1.account.name', 'bbdo', ++ver, null
    adapterSync.version('users.1.name').should.equal constVer

  '''setting a path that contains a ref should update the de-referenced
  ref path ver and its subpath vers''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'accounts.1', { name: 'ogilvy' }, ++ver, null
    adapterSync.set 'users.1.account', {$r: 'accounts.1'}, ++ver, null
    adapterSync.set 'users.1.account.name', 'bbdo', ++ver, null
    adapterSync.version('accounts.1.name').should.equal ver
    adapterSync.version('accounts.1').should.equal ver
    adapterSync.version('accounts').should.equal ver

  '''the version of a ref literal should be the version of the time it
  was set as the literal, not subsequent versions associated with 
  updates to the object it points to''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'accounts.1', { name: 'ogilvy' }, ++ver, null
    adapterSync.set 'users.1.account', {$r: 'accounts.1'}, constVer = ++ver, null
    adapterSync.set 'users.1.account.name', 'bbdo', ++ver, null
    adapterSync._vers.users[1].account.ver.should.eql constVer


  # TODO Move the following commented out tests to Model layer. Doesn't belong in Adapter layer, since Model normalizes array ref ops args before passing the transaction op to the Adapter.
  # Array Ref Path Versioning
#  'pushing on a path that is an array ref should update the path ver': ->
#    adapterSync = new AdapterSync
#    ver = 0
#    adapterSync.set 'users',
#      1: { name: 'cartman', friendIds: ['2', '3'] }
#      2: { name: 'stan' }
#      3: { name: 'kyle' }
#    , ++ver, null
#    adapterSync.set 'users.1.friends', { $r: 'users', $k: 'users.1.friendIds' }, ++ver, null
#    adapterSync.push 'users.1.friends',
#      id: '4'
#      name: 'kenny'
#    , ++ver, null
#    adapterSync.version('users.1.friends').should.equal ver
#
#  '''pushing a path that is an array ref should set the new member
#  version if the member is not yet stored in the model''': ->
#    adapterSync = new AdapterSync
#    ver = 0
#    adapterSync.set 'users',
#      1: { id: '1', name: 'cartman', friendIds: ['2', '3'] }
#      2: { id: '2', name: 'stan' }
#      3: { id: '3', name: 'kyle' }
#    , ++ver, null
#    adapterSync.set 'users.1.friends', { $r: 'users', $k: 'users.1.friendIds' }, ++ver, null
#    adapterSync.push 'users.1.friends',
#      id: '4'
#      name: 'kenny'
#    , ++ver, null
#    adapterSync.version('users.4').should.equal ver
#
#
#  '''pushing a path that is an array ref should not set the new member
#  version if the member is already stored in the model''': ->
#    # This test only passes if versions are set pro-actively for
#    # all nodes of object_literal where e.g., adapter.set(path, object_literal)
#    adapterSync = new AdapterSync
#    ver = 0
#    adapterSync.set 'users',
#      1: { id: '1', name: 'cartman', friendIds: ['2', '3'] }
#      2: { id: '2', name: 'stan' }
#      3: { id: '3', name: 'kyle' }
#      4: { id: '4', name: 'kenny' }
#    , constVer = ++ver, null
#    adapterSync.set 'users.1.friends', { $r: 'users', $k: 'users.1.friendIds' }, ++ver, null
#    adapterSync.push 'users.1.friends', adapterSync.get('users.4'), ++ver, null
#    adapterSync.version('users.4').should.equal constVer
#
#  '''pushing a path that is an array ref should update the version of
#  the array ref key''': ->
#    adapterSync = new AdapterSync
#    ver = 0
#    adapterSync.set 'users',
#      1: { id: '1', name: 'cartman', friendIds: ['2', '3'] }
#      2: { id: '2', name: 'stan' }
#      3: { id: '3', name: 'kyle' }
#      4: { id: '4', name: 'kenny' }
#    , ++ver, null
#    adapterSync.set 'users.1.friends', { $r: 'users', $k: 'users.1.friendIds' }, ++ver, null
#    adapterSync.push 'users.1.friends', adapterSync.get('users.4'), ++ver, null
#    console.log require('util').inspect(adapterSync._vers, false, 10)
#    console.log require('util').inspect(adapterSync.get(), false, 10)
#    adapterSync.version('users.1.friendIds').should.equal ver
#
#  '''pushing a path that is an array ref should not update the version
#  of the object literal representing the array ref pointer''': ->
#    adapterSync = new AdapterSync
#    ver = 0
#    adapterSync.set 'users',
#      1: { id: '1', name: 'cartman', friendIds: ['2', '3'] }
#      2: { id: '2', name: 'stan' }
#      3: { id: '3', name: 'kyle' }
#      4: { id: '4', name: 'kenny' }
#    , ++ver, null
#    adapterSync.set 'users.1.friends', { $r: 'users', $k: 'users.1.friendIds' }, constVer = ++ver, null
#    adapterSync.push 'users.1.friends', adapterSync.get('users.4'), ++ver, null
#    {ver: refVer} = adapterSync.lookup 'users.1.friends', undefined, dontFollowLastRef: true
#    refVer.should.equal constVer
#
  '''setting a path that includes an array ref as part of it + specifying a version
  should update all de-referenced subpaths of the document being updated''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'users',
      1: { id: '1', name: 'cartman', friendIds: ['2', '3'] }
      2: { id: '2', name: 'stan' }
      3: { id: '3', name: 'kyle' }
      4: { id: '4', name: 'kenny' }
    , ++ver, null
    adapterSync.set 'users.1.friends', { $r: 'users', $k: 'users.1.friendIds' }, ++ver, null
    adapterSync.set 'users.1.friends.0.name', 'butters', ++ver, null
    adapterSync.version('users.2.name').should.equal ver
    adapterSync.version('users.2').should.equal ver
    adapterSync.version('users').should.equal ver

  '''setting a path that includes an array ref as part of it + specifying a version
  should not update the version of the array that the array ref key points to''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'users',
      1: { id: '1', name: 'cartman', friendIds: ['2', '3'] }
      2: { id: '2', name: 'stan' }
      3: { id: '3', name: 'kyle' }
      4: { id: '4', name: 'kenny' }
    , constVer = ++ver, null
    adapterSync.set 'users.1.friends', { $r: 'users', $k: 'users.1.friendIds' }, ++ver, null
    adapterSync.set 'users.1.friends.0.name', 'butters', ++ver, null
    adapterSync.version('users.1.friendIds').should.equal constVer

  '''setting a path that includes an array ref as part of it + specifying a version
  should not update sibling path versions''': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'users',
      1: { id: '1', name: 'cartman', friendIds: ['2', '3'] }
      2: { id: '2', name: 'stan' }
      3: { id: '3', name: 'kyle' }
      4: { id: '4', name: 'kenny' }
    , constVer = ++ver, null
    adapterSync.set 'users.1.friends', { $r: 'users', $k: 'users.1.friendIds' }, ++ver, null
    adapterSync.set 'users.1.friends.0.name', 'butters', ++ver, null
    adapterSync.version('users.2.id').should.equal constVer

  'an undefined path should have the root version': ->
    adapterSync = new AdapterSync
    ver = 0
    adapterSync.set 'color', 'red', ++ver, null
    adapterSync.version('direction').should.equal ver

  # TODO Add move tests
