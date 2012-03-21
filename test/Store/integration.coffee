# Theses tests should be run against each adapter
{merge} = require '../../lib/util'
racer = require '../../lib/racer'

shouldPassPubSubIntegrationTests = require './integration.pubSub'
shouldPassTransactionIntegrationTests = require './integration.txns'

module.exports = (storeOpts = {}) ->

  for mode in racer.Store.MODES
    describe mode, ->
      beforeEach (done) ->
        opts = merge {mode}, storeOpts
        store = @store = racer.createStore opts
        store.flush done

      afterEach (done) ->
        @store.flush done

      shouldPassPubSubIntegrationTests()
      shouldPassTransactionIntegrationTests()
