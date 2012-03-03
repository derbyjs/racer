{expect} = require './util'
{run} = require './util/store'
{mockFullSetup} = require './util/model'

require('./journalAdapter') type: 'Memory', null, (run) ->

  run 'Memory journal flushing', (getStore) ->

    it 'should reset everything in the journal',
      mockFullSetup getStore, (model, done) ->
        store = getStore()
        journal = store._journal
        clientId = model._clientId
        journal.startId (origStartId) ->
          model.set '_test.color', 'green', ->
            expect(journal._txns.length).to.equal 1
            expect(journal._txnClock[clientId]).to.be.above 0
            # Without the timeout, origStartId could equal startId
            setTimeout ->
              store.flushJournal (err) ->
                expect(err).to.be.null()
                expect(journal._txns).to.be.empty()
                expect(journal._txnClock).to.eql({})
                expect(journal._startId).to.not.equal(origStartId)
                done()
            , 1
