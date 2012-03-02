{run} = require './util/store'
{expect} = require './util'
racer = require '../src/racer'
transaction = require '../src/transaction'

# TODO Run for all store modes
run 'Store (all memory defaults)', {}, (getStore) ->
  describe '#flush', ->
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

  describe 'subscribing', ->

    # TODO: Move to subscribe tests
    it 'subscribe should only copy the appropriate properties', (done) ->
      store = getStore()
      tests =
        '': {a: {b: 1, c: 2, d: [1, 2]}, e: {c: 7}}
        'a': {a: {b: 1, c: 2, d: [1, 2]}}
        'a.b': {a: {b: 1}}
        'a.d': {a: {d: [1, 2]}}
        '*.c': {a: {c: 2}, e: {c: 7}}

      patterns = Object.keys tests
      count = patterns.length
      finish = -> done() unless --count
      store.set 'a', {b: 1, c: 2, d: [1, 2]}, null, ->
        store.set 'e', {c: 7}, null, ->
          patterns.forEach (pattern) ->
            expected = tests[pattern]
            model = store.createModel()
            model.subscribe pattern, ->
              expect(model.get()).to.specEql expected
              finish()

    it 'store._commit should apply transactions in order', (done) ->
      store = getStore()
      idIn = []
      idOut = []
      finish = ->
        expect(idIn).to.eql idOut
        done()
      for i in [0..9]
        idIn.push id = "1.#{i}"
        txn = transaction.create(base: 0, id: id, method: 'set', args: ['stuff', 0])
        store._commit txn, (err, txn) ->
          idOut.push transaction.id txn
          finish() if idOut.length is 10

    # TODO tests:
    # 'should, upon socket.io disconnect, remove the socket from the sockets._byClientID index'
