should = require 'should'
wrapTest = require('../util').wrapTest

module.exports = (Adapter) ->

  'test get and set': wrapTest (done) ->
    adapter = new Adapter
    adapter.get null, (err, value, ver) ->
      should.equal null, err
      value.should.eql {}
      ver.should.eql 0
      
      adapter.set 'color', 'green', 1, (err, value) ->
        should.equal null, err
        value.should.eql 'green'
        adapter.get 'color', (err, value, ver) ->
          should.equal null, err
          value.should.eql 'green'
          ver.should.eql 1
          
          adapter.set 'info.numbers', {first: 2, second: 10}, 2, (err, value) ->
            should.equal null, err
            value.should.eql first: 2, second: 10
            adapter.get 'info.numbers', (err, value, ver) ->
              should.equal null, err
              value.should.eql first: 2, second: 10
              ver.should.eql 2
              adapter.get null, (err, value, ver) ->
                should.equal null, err
                value.should.eql
                  color: 'green'
                  info:
                    numbers:
                      first: 2
                      second: 10
                ver.should.eql 2
                
                adapter.set 'info', 'new', 3, (err, value) ->
                  should.equal null, err
                  adapter.get null, (err, value, ver) ->
                    should.equal null, err
                    value.should.eql color: 'green', info: 'new'
                    ver.should.eql 3
                    done()

  'test del': wrapTest (done) ->
    adapter = new Adapter
    adapter.set 'color', 'green', 1, ->
      adapter.set 'info.numbers', {first: 2, second: 10}, 2, ->
        adapter.del 'color', 3, (err) ->
          should.equal null, err
          adapter.get null, (err, value, ver) ->
            should.equal null, err
            value.should.eql
              info:
                numbers:
                  first: 2
                  second: 10
            ver.should.eql 3
            
            adapter.del 'info.numbers', 4, (err) ->
              should.equal null, err
              adapter.get null, (err, value, ver) ->
                should.equal null, err
                value.should.eql info: {}
                ver.should.eql 4
                done()

  'test flush': wrapTest (done) ->
    adapter = new Adapter
    adapter.set 'color', 'green', 1, ->
      adapter.flush (err) ->
        should.equal null, err
        adapter.get null, (err, value, ver) ->
          should.equal null, err
          value.should.eql {}
          ver.should.eql 0
          done()

  'should be able to push a single value onto an undefined path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.push 'colors', 'green', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.eql ['green']
        ver.should.eql _ver
        done()

  'should be able to pop from a single member array path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.push 'colors', 'green', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.eql ['green']
        ver.should.eql _ver
        adapter.pop 'colors', ++_ver, (err) ->
          should.equal null, err
          adapter.get 'colors', (err, value, ver) ->
            should.equal null, err
            value.should.eql []
            ver.should.eql _ver
            done()

  'should be able to push multiple members onto an array path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.push 'colors', 'green', ++_ver, (err) ->
      should.equal null, err
      adapter.push 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['green', 'red', 'blue', 'purple']
          ver.should.equal _ver
          done()

  'should be able to pop from a multiple member array path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.push 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
      should.equal null, err
      adapter.pop 'colors', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['red', 'blue']
          ver.should.equal _ver
          done()

  'pop on a non array should result in a "Not an Array" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      should.equal null, err
      adapter.pop 'nonArray', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Not an Array'
        done()

  'push on a non array should result in a "Not an Array" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      should.equal null, err
      adapter.push 'nonArray', 5, 6, ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Not an Array'
        done()

  'should be able to unshift a single value onto an undefined path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.unshift 'colors', 'green', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.eql ['green']
        ver.should.equal _ver
        done()

  'should be able to shift from a single member array path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.unshift 'colors', 'green', ++_ver, (err) ->
      should.equal null, err
      adapter.shift 'colors', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql []
          ver.should.equal _ver
          done()

  'should be able to unshift multiple members onto an array path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.unshift 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.eql ['red', 'blue', 'purple']
        ver.should.equal _ver
        done()

  'should be able to shift from a multiple member array path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.unshift 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
      should.equal null, err
      adapter.shift 'colors', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          value.should.eql ['blue', 'purple']
          ver.should.equal _ver
          done()

  'shift on a non array should result in a "Not an Array" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      should.equal null, err
      adapter.shift 'nonArray', ++_ver, (err, value, ver) ->
        err.should.not.be.null
        err.message.should.equal 'Not an Array'
        done()

  'unshift on a non array should result in a "Not an Array" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      should.equal null, err
      adapter.unshift 'nonArray', 5, 6, ++_ver, (err, value, ver) ->
        err.should.not.be.null
        err.message.should.equal 'Not an Array'
        done()

  'insertAfter -1 on an undefined path should result in a new array': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.insertAfter 'colors', -1, 'yellow', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.eql ['yellow']
        ver.should.equal _ver
        done()

  '''insertAfter -1 on an empty array should fill the array with
  only those elements''': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', [], ++_ver, (err) ->
      should.equal null, err
      adapter.insertAfter 'colors', -1, 'yellow', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['yellow']
          ver.should.equal _ver
          done()

  '''insertAfter the length-1 of an array should act like a push
  on the array''': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertAfter 'colors', 0, 'black', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['yellow', 'black']
          ver.should.equal _ver
          done()

  '''insertAfter should be able to insert in-between an array
  with length>=2''': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertAfter 'colors', 0, 'violet', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['yellow', 'violet', 'black']
          ver.should.equal _ver
          done()

  'insertAfter == length should throw an "Out of Bounds" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertAfter 'colors', 2, 'violet', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Out of Bounds'
        done()

  'insertAfter > length should throw an "Out of Bounds" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertAfter 'colors', 100, 'violet', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Out of Bounds'
        done()

  'insertAfter < -1 should throw an "Out of Bounds" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertAfter 'colors', -2, 'violet', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Out of Bounds'
        done()

  'insertAfter on a non array should throw a "Not an Array" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      should.equal null, err
      adapter.insertAfter 'nonArray', -1, 'never added', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Not an Array'
        done()

  'insertBefore 0 on an undefined path should result in a new array': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.insertBefore 'colors', 0, 'yellow', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.eql ['yellow']
        ver.should.equal _ver
        done()

  '''insertBefore 0 on an empty array should fill the array
  with only those elements''': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', [], ++_ver, (err) ->
      should.equal null, err
      adapter.insertBefore 'colors', 0, 'yellow', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['yellow']
          ver.should.equal _ver
          done()

  'insertBefore 0 in an array should act like a shift': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertBefore 'colors', 0, 'violet', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['violet', 'yellow', 'black']
          ver.should.equal _ver
          done()

  'insertBefore the length of an array should act like a push': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertBefore 'colors', 2, 'violet', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['yellow', 'black', 'violet']
          ver.should.equal _ver
          done()

  'insertBefore should be able to insert in-between an array with length>=2': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['violet', 'yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertBefore 'colors', 1, 'orange', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.eql ['violet', 'orange', 'yellow', 'black']
          ver.should.equal _ver
          done()

  'insertBefore -1 should throw an "Out of Bounds" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertBefore 'colors', -1, 'violet', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Out of Bounds'
        done()

  'insertBefore == length+1 should throw an "Out of Bounds" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertBefore 'colors', 2, 'violet', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Out of Bounds'
        done()

  'insertBefore > length+1 should throw an "Out of Bounds" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow'], ++_ver, (err) ->
      should.equal null, err
      adapter.insertBefore 'colors', 3, 'violet', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Out of Bounds'
        done()

  'insertBefore on a non-array should throw a "Not an Array" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      should.equal null, err
      adapter.insertBefore 'nonArray', 0, 'never added', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Not an Array'
        done()

  # TODO Add remove tests
  # TODO Add splice tests
