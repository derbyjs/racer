{expect} = require '../util'
{mockFullSetup} = require '../util/model'
{finishAfter} = require '../../lib/util/async'

module.exports = ->
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
          patterns.forEach (pattern) ->
            expected = tests[pattern]
            methods.forEach (method) ->
              model = store.createModel()
              model[method] pattern, ->
                expect(model.get('globals._')).to.eql expected
                finish()
