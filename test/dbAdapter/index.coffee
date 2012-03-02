{expect} = require '../util'
{runFn} = require '../util/store'
racer = require '../../src/racer'

module.exports = (options, plugin, moreTests) -> describe "#{options.type} db adapter", ->
  racer.use plugin  if plugin
  run = runFn db: options
  moreTests? run

  run 'store mutators', require './storeMutators'

  run 'db flushing', (getStore) ->
    it 'should delete all db contents', (done) ->
      store = getStore()
      store.set 'color', 'green', 1, (err) ->
        expect(err).to.be.null()
        store.get 'color', (err, value, ver) ->
          expect(err).to.be.null()
          expect(value).to.equal('green')
          store.flushDb (err) ->
            expect(err).to.be.null()
            store.get 'color', (err, value, ver) ->
              expect(err).to.be.null()
              expect(value).to.be(undefined)
              done()
