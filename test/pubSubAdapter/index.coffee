{expect} = require '../util'
{adapter} = require '../util/store'

module.exports = adapter 'pubSub', (run) ->

  run '', (getStore) ->

    it '', ->
      


# transaction = require '../../src/transaction'

#     # TODO: Move to subscribe tests
#     it 'subscribe should only copy the appropriate properties', (done) ->
#       store = getStore()
#       tests =
#         '': {a: {b: 1, c: 2, d: [1, 2]}, e: {c: 7}}
#         'a': {a: {b: 1, c: 2, d: [1, 2]}}
#         'a.b': {a: {b: 1}}
#         'a.d': {a: {d: [1, 2]}}
#         '*.c': {a: {c: 2}, e: {c: 7}}

#       patterns = Object.keys tests
#       count = patterns.length
#       finish = -> done() unless --count
#       store.set 'a', {b: 1, c: 2, d: [1, 2]}, null, ->
#         store.set 'e', {c: 7}, null, ->
#           patterns.forEach (pattern) ->
#             expected = tests[pattern]
#             model = store.createModel()
#             model.subscribe pattern, ->
#               expect(model.get()).to.specEql expected
#               finish()