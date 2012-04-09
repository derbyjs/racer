{expect} = require './util'
{mockFullSetup} = require './util/model'
racer = require '../lib/racer'
shouldBehaveLikeJournalAdapter = require './journalAdapter'

describe 'Memory journal adapter', ->

  shouldBehaveLikeJournalAdapter()

  describe 'flushing', ->
    beforeEach (done) ->
      store = @store = racer.createStore() # TODO per db adapter?
      store.flush done

    afterEach (done) ->
      @store.flush =>
        @store.disconnect()
        done()

    it 'should reset everything in the journal', (done) ->
      store = @store
      mockFullSetup store, done, (model, done) ->
        journal = store._journal
        clientId = model._clientId
        journal.startId (origStartId) ->
          model.set '_test.color', 'green', ->
            expect(journal._txns.length).to.equal 1

            # TODO Add this to another test
            # expect(journal._txnClock[clientId]).to.be.above 0

            # Without the timeout, origStartId could equal startId
            setTimeout ->
              store.flushJournal (err) ->
                expect(err).to.be.null()
                expect(journal._txns).to.be.empty()
                # TODO Add this to another test
                # expect(journal._txnClock).to.eql({})
                expect(journal._startId).to.not.equal(origStartId)
                done()
            , 1
