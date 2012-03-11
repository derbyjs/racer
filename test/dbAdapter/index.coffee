{expect} = require '../util'
{adapter} = require '../util/store'

# `adapter('db', block)` generates the exported
# function (dbOptions, plugin, moreTests)
# that runs `block` for the given `plugin`
module.exports = adapter 'db', (run) ->

  run 'store mutators', require './storeMutators'
  run 'query', {noFlush: true}, require './query'

  run 'db flushing', (getStore) ->
    it 'should delete all db contents', (done) ->
      store = getStore()
      store.set 'globals._.color', 'green', 1, (err) ->
        expect(err).to.be.null()
        store.get 'globals._.color', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.equal('green')
          store.flushDb (err) ->
            expect(err).to.be.null()
            store.get 'globals._.color', (err, value, ver) ->
              expect(err).to.be.null()
              expect(value).to.be(undefined)
              done()
