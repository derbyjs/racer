{expect} = require '../util'
{mockFullSetup} = require '../util/model'
{finishAfter} = require '../../src/util'

module.exports = (getStore) ->

  it 'model.fetch & model.subscribe should retrieve items for a path pattern on the server', (done) ->
    store = getStore()
    tests =
      '': {a: {b: 1, c: 2, d: [1, 2]}, e: {c: 7}}
      'a': {a: {b: 1, c: 2, d: [1, 2]}}
      'a.b': {a: {b: 1}}
      'a.d': {a: {d: [1, 2]}}
      '*.c': {a: {c: 2}, e: {c: 7}}

    patterns = Object.keys tests
    finish = finishAfter patterns.length, done
    store.set 'a', {b: 1, c: 2, d: [1, 2]}, null, ->
      store.set 'e', {c: 7}, null, ->
        patterns.forEach (pattern) ->
          expected = tests[pattern]
          ['subscribe', 'fetch'].forEach (method) ->
            model = store.createModel()
            model[method] pattern, ->
              expect(model.get()).to.eql expected
              finish()
