{expect} = require '../util'
shouldWorkWithStoreMutators = require './storeMutators'
shouldBeAbleToQuery = require './query'
shouldPassStoreIntegrationTests = require '../Store/integration'
racer = require '../../lib/racer'

shouldBehaveLikeDbAdapter = module.exports = (storeOpts = {}, plugins = []) ->
  shouldWorkWithStoreMutators(storeOpts, plugins)
  shouldBeAbleToQuery(storeOpts, plugins)

  describe 'db flushing', ->
    beforeEach (done) ->
      for plugin, i in plugins
        pluginOpts = plugin.testOpts
        racer.use plugin, pluginOpts if plugin.useWith.server
      @store = racer.createStore(storeOpts)
      @store.flush done

    afterEach (done) ->
      @store.flush =>
        @store.disconnect()
        done()

    it 'should delete all db contents', (done) ->
      store = @store
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

  shouldPassStoreIntegrationTests storeOpts
