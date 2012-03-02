{run} = require './util/store'
plugin = null
{expect} = require './util'

require('./journalAdapter') type: 'Memory', plugin, ->
  run 'journal flushing', {mode: 'stm', journal: { type: 'Memory' } }, (getStore) ->
    it 'should reset everything in the journal', (done) ->
      store = getStore()
      journal = store._journal
      journal.startId (origStartId) ->
        # Without the timeout, origStartId sometimes equals startId
        setTimeout ->
          store.flushJournal (err) ->
            expect(err).to.be.null()
            expect(journal._txns).to.be.empty()
            expect(journal._txnClock).to.eql({})
            expect(journal._startId).to.not.equal(origStartId)
            done()
        , 10
