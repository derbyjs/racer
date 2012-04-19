# Theses tests should be run against each adapter
{merge} = require '../../lib/util'
racer = require '../../lib/racer'
{augmentStoreOpts} = require '../journalAdapter/util'

shouldPassPubSubIntegrationTests = require './integration.pubSub'
shouldPassTransactionIntegrationTests = require './integration.txns'

module.exports = (storeOpts = {}, plugins = []) ->

  describe 'Store integration tests', ->

    racer.protected.Store.MODES.forEach (mode) ->
      describe mode, ->
        beforeEach (done) ->
          for plugin in plugins
            racer.use plugin, plugin.testOpts if plugin.useWith.server
          opts = augmentStoreOpts storeOpts, mode
          store = @store = racer.createStore opts
          store.flush done

        afterEach (done) ->
          @store.flush done

        shouldPassPubSubIntegrationTests plugins
        shouldPassTransactionIntegrationTests plugins
