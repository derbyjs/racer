{expect} = require '../util'
{finishAfter} = require '../../lib/util/async'
racer = require '../../lib/racer'
{isServer} = require '../../lib/util'
{augmentStoreOpts} = require '../journalAdapter/util'

# TODO Add remove tests
# TODO Add more move tests

module.exports = (storeOpts = {}, plugins = []) ->
  describe 'store mutators', ->

    beforeEach (done) ->
      for plugin, i in plugins
        pluginOpts = plugin.testOpts
        racer.use plugin, pluginOpts if plugin.useWith.server
      opts = augmentStoreOpts storeOpts, 'lww'
      @store = racer.createStore opts
      @store.flush done

    afterEach (done) ->
      @store.flush =>
        @store.disconnect()
        done()

    it 'get and set', (done) ->
      store = @store
      store.get 'globals._.info.numbers', (err, value, ver) ->
        expect(err).to.be.null()
        expect(value).to.be undefined
        expect(ver).to.eql 0

        store.set 'globals._.info.numbers', {first: 2, second: 10}, 1, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.info.numbers', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql first: 2, second: 10
            expect(ver).to.eql 1
            store.get 'globals._.info', (err, value, ver) ->
              expect(err).to.be.null()
              expect(value).to.specEql
                numbers:
                  first: 2
                  second: 10
              expect(ver).to.eql 1

              store.set 'globals._.info', 'new', 2, (err) ->
                expect(err).to.be.null()
                store.get 'globals._.info', (err, value, ver) ->
                  expect(err).to.be.null()
                  expect(value).to.specEql 'new'
                  expect(ver).to.eql 2
                  done()

    it 'del', (done) ->
      store = @store
      store.set 'globals._.color', 'green', 1, ->
        store.set 'globals._.info.numbers', {first: 2, second: 10}, 2, ->
          store.del 'globals._.color', 3, (err) ->
            expect(err).to.be.null()
            store.get 'globals._', (err, value, ver) ->
              expect(err).to.be.null()
              expect(value).to.specEql
                id: '_'
                info:
                  numbers:
                    first: 2
                    second: 10
              expect(ver).to.eql 3

              store.del 'globals._.info.numbers', 4, (err) ->
                expect(err).to.be.null()
                store.get 'globals._', (err, value, ver) ->
                  expect(err).to.be.null()
                  expect(value).to.specEql id: '_', info: {}
                  expect(ver).to.eql 4
                  done()

    it 'flush', (done) ->
      store = @store
      store.set 'globals._.color', 'green', 1, ->
        store.flush (err) ->
          expect(err).to.be.null()
          store.get 'globals._', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql {}
            expect(ver).to.eql 0
            done()

    it 'should be able to push a single value onto an undefined path', (done) ->
      store = @store
      _ver = 0
      store.push 'globals._.colors', ['green'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.get 'globals._.colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['green']
          expect(ver).to.eql _ver
          done()

    it 'should be able to pop from a single member array path', (done) ->
      store = @store
      _ver = 0
      store.push 'globals._.colors', ['green'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.get 'globals._.colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['green']
          expect(ver).to.eql _ver
          store.pop 'globals._.colors', ++_ver, (err) ->
            expect(err).to.be.null()
            store.get 'globals._.colors', (err, value, ver) ->
              expect(err).to.be.null()
              expect(value).to.specEql []
              expect(ver).to.eql _ver
              done()

    it 'should be able to push multiple members onto an array path', (done) ->
      store = @store
      _ver = 0
      store.push 'globals._.colors', ['green'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.push 'globals._.colors', ['red', 'blue', 'purple'], ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql ['green', 'red', 'blue', 'purple']
            expect(ver).to.equal _ver
            done()

    it 'should be able to pop from a multiple member array path', (done) ->
      store = @store
      _ver = 0
      store.push 'globals._.colors', ['red', 'blue', 'purple'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.pop 'globals._.colors', ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql ['red', 'blue']
            expect(ver).to.equal _ver
            done()

    it 'pop on a non array should result in a "Not an Array" error', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.nonArray', '9', ++_ver, (err) ->
        expect(err).to.be.null()
        store.pop 'globals._.nonArray', ++_ver, (err) ->
          expect(err).to.not.be.null
          expect(err.message.toLowerCase()).to.contain 'not an array'
          done()

    it 'push on a non array should result in a "Not an Array" error', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.nonArray', '9', ++_ver, (err) ->
        expect(err).to.be.null()
        store.push 'globals._.nonArray', [5, 6], ++_ver, (err) ->
          expect(err).to.not.be.null
          expect(err.message.toLowerCase()).to.contain 'not an array'
          done()

    it 'should be able to unshift a single value onto an undefined path', (done) ->
      store = @store
      _ver = 0
      store.unshift 'globals._.colors', ['green'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.get 'globals._.colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['green']
          expect(ver).to.equal _ver
          done()

    it 'should be able to shift from a single member array path', (done) ->
      store = @store
      _ver = 0
      store.unshift 'globals._.colors', ['green'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.shift 'globals._.colors', ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql []
            expect(ver).to.equal _ver
            done()

    it 'should be able to unshift multiple members onto an array path', (done) ->
      store = @store
      _ver = 0
      store.unshift 'globals._.colors', ['red', 'blue', 'purple'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.get 'globals._.colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['red', 'blue', 'purple']
          expect(ver).to.equal _ver
          done()

    it 'should be able to shift from a multiple member array path', (done) ->
      store = @store
      _ver = 0
      store.unshift 'globals._.colors', ['red', 'blue', 'purple'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.shift 'globals._.colors', ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(value).to.specEql ['blue', 'purple']
            expect(ver).to.equal _ver
            done()

    it 'shift on a non array should result in a "Not an Array" error', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.nonArray', '9', ++_ver, (err) ->
        expect(err).to.be.null()
        store.shift 'globals._.nonArray', ++_ver, (err, value, ver) ->
          expect(err).to.not.be.null
          expect(err.message.toLowerCase()).to.contain 'not an array'
          done()

    it 'unshift on a non array should result in a "Not an Array" error', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.nonArray', '9', ++_ver, (err) ->
        expect(err).to.be.null()
        store.unshift 'globals._.nonArray', [5, 6], ++_ver, (err, value, ver) ->
          expect(err).to.not.be.null
          expect(err.message.toLowerCase()).to.contain 'not an array'
          done()

    it 'insert 0 on an undefined path should result in a new array', (done) ->
      store = @store
      _ver = 0
      store.insert 'globals._.colors', 0, ['yellow'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.get 'globals._.colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['yellow']
          expect(ver).to.equal _ver
          done()

    it 'insert 0 on an empty array should fill the array with only those elements', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.colors', [], ++_ver, (err) ->
        expect(err).to.be.null()
        store.insert 'globals._.colors', 0, ['yellow'], ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql ['yellow']
            expect(ver).to.equal _ver
            done()

    it 'insert 0 in an array should act like a shift', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.colors', ['yellow', 'black'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.insert 'globals._.colors', 0, ['violet'], ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql ['violet', 'yellow', 'black']
            expect(ver).to.equal _ver
            done()

    it 'insert the length of an array should act like a push', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.colors', ['yellow', 'black'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.insert 'globals._.colors', 2, ['violet'], ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql ['yellow', 'black', 'violet']
            expect(ver).to.equal _ver
            done()

    it 'insert should be able to insert in-between an array with length>=2', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.colors', ['violet', 'yellow', 'black'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.insert 'globals._.colors', 1, ['orange'], ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql ['violet', 'orange', 'yellow', 'black']
            expect(ver).to.equal _ver
            done()

    it 'insert on a non-array should throw a "Not an Array" error', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.nonArray', '9', ++_ver, (err) ->
        expect(err).to.be.null()
        store.insert 'globals._.nonArray', 0, ['never added'], ++_ver, (err) ->
          expect(err).to.not.be.null
          expect(err.message.toLowerCase()).to.contain 'not an array'
          done()

    it 'moving from index A to index B should work', (done) ->
      store = @store
      _ver = 0
      store.set 'globals._.colors', ['red', 'orange', 'yellow', 'green', 'blue'], ++_ver, (err) ->
        expect(err).to.be.null()
        store.move 'globals._.colors', 1, 3, 1, ++_ver, (err) ->
          expect(err).to.be.null()
          store.get 'globals._.colors', (err, value, ver) ->
            expect(err).to.be.null()
            expect(value).to.specEql ['red', 'yellow', 'green', 'orange', 'blue']
            expect(ver).to.equal _ver
            done()

    it 'should end up in the intended state after a series of rapid inserts on the same path', (done) ->
      store = @store
      finish = finishAfter 3, ->
        store.get 'globals._.colors', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.specEql ['THREE', 'TWO', 'ONE']
          expect(ver).to.equal _ver
          done()
      _ver = 0
      store.insert 'globals._.colors', 0, ['ONE'], ++_ver, (err) ->
        expect(err).to.be.null()
        finish()
      store.insert 'globals._.colors', 0, ['TWO'], ++_ver, (err) ->
        expect(err).to.be.null()
        finish()
      store.insert 'globals._.colors', 0, ['THREE'], ++_ver, (err) ->
        expect(err).to.be.null()
        finish()
