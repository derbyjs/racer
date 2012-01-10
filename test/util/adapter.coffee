should = require 'should'
{wrapTest} = require '../util'

module.exports = (Adapter) ->

  'test get and set': wrapTest (done) ->
    adapter = new Adapter
    adapter.get null, (err, value, ver) ->
      should.equal null, err
      value.should.specEql {}
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
            value.should.specEql first: 2, second: 10
            adapter.get 'info.numbers', (err, value, ver) ->
              should.equal null, err
              value.should.specEql first: 2, second: 10
              ver.should.eql 2
              adapter.get null, (err, value, ver) ->
                should.equal null, err
                value.should.specEql
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
                    value.should.specEql color: 'green', info: 'new'
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
            value.should.specEql
              info:
                numbers:
                  first: 2
                  second: 10
            ver.should.eql 3
            
            adapter.del 'info.numbers', 4, (err) ->
              should.equal null, err
              adapter.get null, (err, value, ver) ->
                should.equal null, err
                value.should.specEql info: {}
                ver.should.eql 4
                done()

  'test flush': wrapTest (done) ->
    adapter = new Adapter
    adapter.set 'color', 'green', 1, ->
      adapter.flush (err) ->
        should.equal null, err
        adapter.get null, (err, value, ver) ->
          should.equal null, err
          value.should.specEql {}
          ver.should.eql 0
          done()

  'should be able to push a single value onto an undefined path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.push 'colors', 'green', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.specEql ['green']
        ver.should.eql _ver
        done()

  'should be able to pop from a single member array path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.push 'colors', 'green', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.specEql ['green']
        ver.should.eql _ver
        adapter.pop 'colors', ++_ver, (err) ->
          should.equal null, err
          adapter.get 'colors', (err, value, ver) ->
            should.equal null, err
            value.should.specEql []
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
          value.should.specEql ['green', 'red', 'blue', 'purple']
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
          value.should.specEql ['red', 'blue']
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
        value.should.specEql ['green']
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
          value.should.specEql []
          ver.should.equal _ver
          done()

  'should be able to unshift multiple members onto an array path': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.unshift 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.specEql ['red', 'blue', 'purple']
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
          value.should.specEql ['blue', 'purple']
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

  'insert 0 on an undefined path should result in a new array': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.insert 'colors', 0, 'yellow', ++_ver, (err) ->
      should.equal null, err
      adapter.get 'colors', (err, value, ver) ->
        should.equal null, err
        value.should.specEql ['yellow']
        ver.should.equal _ver
        done()

  '''insert 0 on an empty array should fill the array
  with only those elements''': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', [], ++_ver, (err) ->
      should.equal null, err
      adapter.insert 'colors', 0, 'yellow', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.specEql ['yellow']
          ver.should.equal _ver
          done()

  'insert 0 in an array should act like a shift': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insert 'colors', 0, 'violet', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.specEql ['violet', 'yellow', 'black']
          ver.should.equal _ver
          done()

  'insert the length of an array should act like a push': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insert 'colors', 2, 'violet', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.specEql ['yellow', 'black', 'violet']
          ver.should.equal _ver
          done()

  'insert should be able to insert in-between an array with length>=2': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['violet', 'yellow', 'black'], ++_ver, (err) ->
      should.equal null, err
      adapter.insert 'colors', 1, 'orange', ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.specEql ['violet', 'orange', 'yellow', 'black']
          ver.should.equal _ver
          done()

  'insert on a non-array should throw a "Not an Array" error': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      should.equal null, err
      adapter.insert 'nonArray', 0, 'never added', ++_ver, (err) ->
        err.should.not.be.null
        err.message.should.equal 'Not an Array'
        done()

  # TODO Add remove tests

  'moving from index A to index B should work': wrapTest (done) ->
    adapter = new Adapter
    _ver = 0
    adapter.set 'colors', ['red', 'orange', 'yellow', 'green', 'blue'], ++_ver, (err) ->
      should.equal null, err
      adapter.move 'colors', 1, 3, ++_ver, (err) ->
        should.equal null, err
        adapter.get 'colors', (err, value, ver) ->
          should.equal null, err
          value.should.specEql ['red', 'yellow', 'green', 'orange', 'blue']
          ver.should.equal _ver
          done()

  # TODO Add more move tests
