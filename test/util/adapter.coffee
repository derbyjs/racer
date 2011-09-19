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
