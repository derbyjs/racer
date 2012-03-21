{expect} = require '../util'
{merge} = require '../../lib/util'
racer = require '../../lib/racer'
shouldCommitWithSTM = require './stmCommit'
shouldPassStoreIntegrationTests = require '../Store/integration'

module.exports = (storeOpts = {}) ->

  shouldCommitWithSTM()

  describe 'commit', ->
    transaction = require '../../lib/transaction'

    for mode in racer.Store.MODES
      describe mode, ->
        beforeEach (done) ->
          opts = merge {mode}, storeOpts
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
      store = @store = racer.createStore storeOpts
      store.flush done

    afterEach (done) ->
      @store.flush done

    it 'should reset the version', (done) ->
      store = @store
      store.set 'color', 'green', 1, (err) ->
        expect(err).to.be.null()
        store._journal.version (err, ver) ->
          expect(ver).to.be(1)
          store.flush (err) ->
            expect(err).to.be.null()
            store._journal.version (ver) ->
              expect(ver).to.not.be.ok()
              done()

    it 'should return an error if the journal fails to flush', (done) ->
      __flush__ = @store._journal.flush
      @store._journal.flush = (callback) ->
        @flush = __flush__
        callback new Error
      @store.flushJournal (err) ->
        expect(err).to.be.an Error
        done()

  shouldPassStoreIntegrationTests storeOpts
