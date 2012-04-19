{expect} = require '../util'
racer = require '../../lib/racer'
shouldCommitWithSTM = require './stmCommit'
shouldPassStoreIntegrationTests = require '../Store/integration'
{augmentStoreOpts} = require './util'

module.exports = (storeOpts = {}, plugins = []) ->

  shouldCommitWithSTM storeOpts, plugins

  describe 'commit', ->
    transaction = require '../../lib/transaction'

    racer.protected.Store.MODES.forEach (mode) ->
      describe mode, ->
        beforeEach (done) ->
          for plugin in plugins
            racer.use plugin if plugin.useWith.server
          opts = augmentStoreOpts storeOpts, mode
          store = @store = racer.createStore opts
          store.flush done

        afterEach (done) ->
          @store.flush done

        it 'store._commit should apply transactions in order', (done) ->
          store = @store
          idIn = []
          idOut = []
          finish = ->
            expect(idOut).to.eql idIn
            done()
          for i in [0..9]
            idIn.push id = "1.#{i}"
            txn = transaction.create(ver: 0, id: id, method: 'set', args: ['stuff', 0])
            store._commit txn, (err, txn) ->
              idOut.push transaction.getId txn
              finish() if idOut.length is 10

  describe 'flushing', ->
    beforeEach (done) ->
      for plugin in plugins
        racer.use plugin if plugin.useWith.server
      opts = augmentStoreOpts storeOpts, 'lww'
      store = @store = racer.createStore opts
      store.flush done

    afterEach (done) ->
      @store.flush done

    it 'should reset the version', (done) ->
      store = @store
      store.set 'color', 'green', 1, (err) ->
        expect(err).to.be.null()
        store._mode.version (err, ver) ->
          expect(ver).to.be(1)
          store.flush (err) ->
            expect(err).to.be.null()
            store._mode.version (ver) ->
              expect(ver).to.not.be.ok()
              done()

    it 'should return an error if the journal fails to flush', (done) ->
      __flush__ = @store._mode.flush
      @store._mode.flush = (callback) ->
        @flush = __flush__
        callback new Error
      @store.flushMode (err) ->
        expect(err).to.be.an Error
        done()

  shouldPassStoreIntegrationTests storeOpts
