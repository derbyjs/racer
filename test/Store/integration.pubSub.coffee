{expect} = require '../util'
{mockFullSetup} = require '../util/model'
{finishAfter} = require '../../src/util'

module.exports = (getStore) ->

  it 'model.fetch & model.subscribe should retrieve items for a path pattern on the server', (done) ->
    store = getStore()
    tests =
      'globals._': {a: {b: 1, c: 2, d: [1, 2]}, e: {c: 7}, id: '_'}
      'globals._.a': {a: {b: 1, c: 2, d: [1, 2]}}
      'globals._.a.b': {a: {b: 1}}
      'globals._.a.d': {a: {d: [1, 2]}}
      'globals._.*.c': {a: {c: 2}, e: {c: 7}}

    patterns = Object.keys tests
    finish = finishAfter patterns.length, done
    store.set 'globals._.a', {b: 1, c: 2, d: [1, 2]}, null, ->
      store.set 'globals._.e', {c: 7}, null, ->
        patterns.forEach (pattern) ->
          expected = tests[pattern]
          ['subscribe', 'fetch'].forEach (method) ->
            model = store.createModel()
            model[method] pattern, do (method, pattern) -> ->
              expect(model.get('globals._')).to.eql expected
              finish()
