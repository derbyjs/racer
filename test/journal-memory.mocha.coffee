{expect} = require './util'
{mockFullSetup} = require './util/model'
racer = require '../lib/racer'
JournalMemory = require '../lib/adapters/journal-memory'
shouldBehaveLikeJournalAdapter = require './journalAdapter'

describe 'Memory journal adapter', ->

  shouldBehaveLikeJournalAdapter()

  describe 'flushing', ->
    beforeEach (done) ->
      # TODO per db adapter?
      store = @store = racer.createStore
        mode:
          type: 'stm'
      store.flush done

    afterEach (done) ->
      @store.flush =>
        @store.disconnect()
        done()

    it 'should reset everything in the journal', (done) ->
      store = @store
      mockFullSetup store, done, (model, done) ->
        journal = store._mode._journal
        clientId = model._clientId
        journal.startId (origStartId) ->
          model.set '_test.color', 'green', ->
            expect(journal._txns.length).to.equal 1

            # TODO Add this to another test
            # expect(journal._txnClock[clientId]).to.be.above 0

            # Without the timeout, origStartId could equal startId
            setTimeout ->
              journal.flush (err) ->
                expect(err).to.be.null()
                expect(journal._txns).to.be.empty()
                # TODO Add this to another test
                # expect(journal._txnClock).to.eql({})
                expect(journal._startId).to.not.equal(origStartId)
                done()
            , 1
