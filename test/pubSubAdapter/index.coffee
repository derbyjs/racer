{expect} = require './index'
{run} = require './store'
transaction = require '../../src/transaction'
racer = require '../../src/racer'

module.exports = (options, plugin) -> describe "#{options.type} pubSub adapter", ->
  racer.use plugin  if plugin

  run '', {mode: 'stm', pubSub: options}, (getStore) ->

    it '', (done) ->
      

    # TODO: Move to subscribe tests
    it 'subscribe should only copy the appropriate properties', (done) ->
      store = getStore()
      tests =
        '': {a: {b: 1, c: 2, d: [1, 2]}, e: {c: 7}}
        'a': {a: {b: 1, c: 2, d: [1, 2]}}
        'a.b': {a: {b: 1}}
        'a.d': {a: {d: [1, 2]}}
        '*.c': {a: {c: 2}, e: {c: 7}}

      patterns = Object.keys tests
      count = patterns.length
      finish = -> done() unless --count
      store.set 'a', {b: 1, c: 2, d: [1, 2]}, null, ->
        store.set 'e', {c: 7}, null, ->
          patterns.forEach (pattern) ->
            expected = tests[pattern]
            model = store.createModel()
            model.subscribe pattern, ->
              expect(model.get()).to.specEql expected
              finish()