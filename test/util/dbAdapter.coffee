{expect} = require './index'
racer = require '../../src/racer'

module.exports = (options) -> describe "db adapter #{options.type}", ->

  it 'test get and set', (done) ->
    adapter = racer.createAdapter 'db', options
    adapter.get null, (err, value, ver) ->
      expect(err).to.be.null()
      expect(value).to.specEql {}
      expect(ver).to.eql 0

      adapter.set 'color', 'green', 1, (err, value) ->
        expect(err).to.be.null()
        expect(value).to.eql 'green'
        adapter.get 'color', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.eql 'green'
          expect(ver).to.eql 1

          adapter.set 'info.numbers', {first: 2, second: 10}, 2, (err, value) ->
            expect(err).to.be.null()
            expect(value).to.specEql first: 2, second: 10
            adapter.get 'info.numbers', (err, value, ver) ->
              expect(err).to.be.null()
              expect(value).to.specEql first: 2, second: 10
              expect(ver).to.eql 2
              adapter.get null, (err, value, ver) ->
                expect(err).to.be.null()
                expect(value).to.specEql
                  color: 'green'
                  info:
                    numbers:
                      first: 2
                      second: 10
                expect(ver).to.eql 2

                adapter.set 'info', 'new', 3, (err, value) ->
                  expect(err).to.be.null()
                  adapter.get null, (err, value, ver) ->
                    expect(err).to.be.null()
                    expect(value).to.specEql color: 'green', info: 'new'
                    expect(ver).to.eql 3
                    done()

  it 'test del', (done) ->
    adapter = racer.createAdapter 'db', options
    adapter.set 'color', 'green', 1, ->
      adapter.set 'info.numbers', {first: 2, second: 10}, 2, ->
        adapter.del 'color', 3, (err) ->
          expect(err).to.be.null()
          adapter.get null, (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql
              info:
                numbers:
                  first: 2
                  second: 10
            expect(ver).to.eql 3

            adapter.del 'info.numbers', 4, (err) ->
              expect(err).to.be.null()
              adapter.get null, (err, value, ver) ->
                expect(err).to.be.null()
                expect(value).to.specEql info: {}
                expect(ver).to.eql 4
                done()

  it 'test flush', (done) ->
    adapter = racer.createAdapter 'db', options
    adapter.set 'color', 'green', 1, ->
      adapter.flush (err) ->
        expect(err).to.be.null()
        adapter.get null, (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql {}
          expect(ver).to.eql 0
          done()

  it 'should be able to push a single value onto an undefined path', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.push 'colors', 'green', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.get 'colors', (err, value, ver) ->
        expect(err).to.be.null()
        expect(value).to.specEql ['green']
        expect(ver).to.eql _ver
        done()

  it 'should be able to pop from a single member array path', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.push 'colors', 'green', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.get 'colors', (err, value, ver) ->
        expect(err).to.be.null()
        expect(value).to.specEql ['green']
        expect(ver).to.eql _ver
        adapter.pop 'colors', ++_ver, (err) ->
          expect(err).to.be.null()
          adapter.get 'colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql []
            expect(ver).to.eql _ver
            done()

  it 'should be able to push multiple members onto an array path', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.push 'colors', 'green', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.push 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['green', 'red', 'blue', 'purple']
          expect(ver).to.equal _ver
          done()

  it 'should be able to pop from a multiple member array path', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.push 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.pop 'colors', ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['red', 'blue']
          expect(ver).to.equal _ver
          done()

  it 'pop on a non array should result in a "Not an Array" error', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.pop 'nonArray', ++_ver, (err) ->
        expect(err).to.not.be.null
        expect(err.message).to.equal 'Not an Array'
        done()

  it 'push on a non array should result in a "Not an Array" error', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.push 'nonArray', 5, 6, ++_ver, (err) ->
        expect(err).to.not.be.null
        expect(err.message).to.equal 'Not an Array'
        done()

  it 'should be able to unshift a single value onto an undefined path', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.unshift 'colors', 'green', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.get 'colors', (err, value, ver) ->
        expect(err).to.be.null()
        expect(value).to.specEql ['green']
        expect(ver).to.equal _ver
        done()

  it 'should be able to shift from a single member array path', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.unshift 'colors', 'green', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.shift 'colors', ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql []
          expect(ver).to.equal _ver
          done()

  it 'should be able to unshift multiple members onto an array path', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.unshift 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.get 'colors', (err, value, ver) ->
        expect(err).to.be.null()
        expect(value).to.specEql ['red', 'blue', 'purple']
        expect(ver).to.equal _ver
        done()

  it 'should be able to shift from a multiple member array path', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.unshift 'colors', 'red', 'blue', 'purple', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.shift 'colors', ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(value).to.specEql ['blue', 'purple']
          expect(ver).to.equal _ver
          done()

  it 'shift on a non array should result in a "Not an Array" error', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.shift 'nonArray', ++_ver, (err, value, ver) ->
        expect(err).to.not.be.null
        expect(err.message).to.equal 'Not an Array'
        done()

  it 'unshift on a non array should result in a "Not an Array" error', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.unshift 'nonArray', 5, 6, ++_ver, (err, value, ver) ->
        expect(err).to.not.be.null
        expect(err.message).to.equal 'Not an Array'
        done()

  it 'insert 0 on an undefined path should result in a new array', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.insert 'colors', 0, 'yellow', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.get 'colors', (err, value, ver) ->
        expect(err).to.be.null()
        expect(value).to.specEql ['yellow']
        expect(ver).to.equal _ver
        done()

  it 'insert 0 on an empty array should fill the array with only those elements', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'colors', [], ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.insert 'colors', 0, 'yellow', ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['yellow']
          expect(ver).to.equal _ver
          done()

  it 'insert 0 in an array should act like a shift', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.insert 'colors', 0, 'violet', ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['violet', 'yellow', 'black']
          expect(ver).to.equal _ver
          done()

  it 'insert the length of an array should act like a push', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'colors', ['yellow', 'black'], ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.insert 'colors', 2, 'violet', ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['yellow', 'black', 'violet']
          expect(ver).to.equal _ver
          done()

  it 'insert should be able to insert in-between an array with length>=2', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'colors', ['violet', 'yellow', 'black'], ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.insert 'colors', 1, 'orange', ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['violet', 'orange', 'yellow', 'black']
          expect(ver).to.equal _ver
          done()

  it 'insert on a non-array should throw a "Not an Array" error', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'nonArray', '9', ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.insert 'nonArray', 0, 'never added', ++_ver, (err) ->
        expect(err).to.not.be.null
        expect(err.message).to.equal 'Not an Array'
        done()

  # TODO Add remove tests

  it 'moving from index A to index B should work', (done) ->
    adapter = racer.createAdapter 'db', options
    _ver = 0
    adapter.set 'colors', ['red', 'orange', 'yellow', 'green', 'blue'], ++_ver, (err) ->
      expect(err).to.be.null()
      adapter.move 'colors', 1, 3, 1, ++_ver, (err) ->
        expect(err).to.be.null()
        adapter.get 'colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['red', 'yellow', 'green', 'orange', 'blue']
          expect(ver).to.equal _ver
          done()

  # TODO Add more move tests
