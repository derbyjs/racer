{expect} = require '../util'
racer = require '../../lib/racer'

describe 'Store flush', ->
  beforeEach (done) ->
    @store = racer.createStore()
    @store.flush done

  afterEach (done) ->
    @store.flush done

  it 'should flush the db and journal (via mode)', (done) ->
    flushed = {}
    __dbFlush__ = @store._db.flush
    @store._db.flush = (cb) ->
      flushed.db = true
      cb null
      @flush = __dbFlush__

    __journalFlush__ = @store._mode.flush
    @store._mode.flush = (cb) ->
      flushed.journal = true
      cb null
      @flush = __journalFlush__

    @store.flush (err) ->
      expect(err).to.be.null()
      expect(flushed.db).to.be.ok()
      expect(flushed.journal).to.be.ok()
      done()

  it 'should callback with an error if the db adapter fails to flush', (done) ->
    __dbFlush__ = @store._db.flush
    @store._db.flush = (cb) ->
      cb new Error
      @flush = __dbFlush__

    @store.flush (err) ->
      expect(err).to.be.an Error
      done()

  it 'should callback with an error if the journal fails to flush', (done) ->
    __journalFlush__ = @store._mode.flush
    @store._mode.flush = (cb) ->
      cb new Error
      @flush = __journalFlush__

    @store.flush (err) ->
      expect(err).to.be.an Error
      done()

  it 'should callback with a single error if both the adapter and journal fail to flush', (done) ->
    callbackCount = 0

    __dbFlush__ = @store._db.flush
    @store._db.flush = (cb) ->
      cb new Error
      @flush = __dbFlush__

    __journalFlush__ = @store._mode.flush
    @store._mode.flush = (cb) ->
      cb new Error
      @flush = __journalFlush__

    @store.flush (err) ->
      expect(err).to.be.an Error
      expect(++callbackCount).to.eql 1
      done()
