{expect} = require '../util'
{run} = require '../util/store'

run 'Store flush', (getStore) ->

  it 'should flush the db and journal', (done) ->
    store = getStore()
    flushed = {}
    store._db.flush = (cb) ->
      flushed.db = true
      cb null
    store._journal.flush = (cb) ->
      flushed.journal = true
      cb null
    store.flush (err) ->
      expect(err).to.be.null()
      expect(flushed.db).to.be.ok()
      expect(flushed.journal).to.be.ok()
      done()

  it 'should callback with an error if the db adapter fails to flush', (done) ->
    store = getStore()
    store._db.flush = (cb) -> cb new Error
    store.flush (err) ->
      expect(err).to.be.an Error
      done()

  it 'should callback with an error if the journal fails to flush', (done) ->
    store = getStore()
    store._journal.flush = (cb) -> cb new Error
    store.flush (err) ->
      expect(err).to.be.an Error
      done()

  it 'should callback with a single error if both the adapter and journal fail to flush', (done) ->
    store = getStore()
    callbackCount = 0
    store._db.flush = (cb) -> cb new Error
    store._journal.flush = (cb) -> cb new Error
    store.flush (err) ->
      expect(err).to.be.an Error
      expect(++callbackCount).to.eql 1
      done()
