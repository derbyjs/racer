{expect} = require '../util'
{finishAfter} = require '../../lib/util/async'
{mockFullSetup} = require '../util/model'

module.exports = (plugins = []) ->
  describe 'Store pub sub', ->
    it 'model.fetch & model.subscribe should retrieve items for a path pattern on the server', (done) ->
      tests =
        'globals._': {a: {b: 1, c: 2, d: [1, 2]}, e: {c: 7}, id: '_'}
        'globals._.a': {a: {b: 1, c: 2, d: [1, 2]}, id: '_'}
        'globals._.a.b': {a: {b: 1}, id: '_'}
        'globals._.a.d': {a: {d: [1, 2]}, id: '_'}
        'globals._.*.c': {a: {c: 2}, e: {c: 7}, id: '_'}

      methods = ['subscribe', 'fetch']

      patterns = Object.keys tests
      finish = finishAfter patterns.length * methods.length, done
      store = @store
      store.set 'globals._.a', {b: 1, c: 2, d: [1, 2]}, null, ->
        store.set 'globals._.e', {c: 7}, null, ->
          methods.forEach (method) ->
            model = store.createModel()
            model[method] 'globals.notDefined', ->
              expect(model.get 'globals.notDefined').to.eql undefined
              patterns.forEach (pattern) ->
                modelB = store.createModel()
                expected = tests[pattern]
                modelB[method] pattern, ->
                  expect(modelB.get 'globals._').to.eql expected
                  finish()

    it 'should distribute events to refs remotely', (done) ->
      mockFullSetup @store, done, plugins, (modelA, modelB, done) ->
        modelB.on 'set', '_test.text', (val) ->
          expect(val).to.equal 'word'
          done()
        modelA.set '_test.text', 'word'
