{expect} = require '../util'
{merge} = require '../../lib/util'
transaction = require '../../lib/transaction'
racer = require '../../lib/racer'
{augmentStoreOpts} = require './util'

module.exports = (storeOpts = {}, plugins = []) ->

  describe 'STM commit', ->

    beforeEach (done) ->
      for plugin in plugins
        racer.use plugin if plugin.useWith.server
      opts = augmentStoreOpts storeOpts, 'stm'
      store = @store = racer.createStore opts
      store.flush done

    afterEach (done) ->
      @store.flush done

    it 'different-client, different-path, simultaneous transaction should succeed', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create ver: 0, id: '2.0', method: 'set', args: ['favorite-skittle', 'red']
      @store._commit txnOne, (err) ->
        expect(err).to.be.null()
      @store._commit txnTwo, (err) ->
        expect(err).to.be.null()
        done()

    it 'different-client, same-path, simultaneous transaction should fail', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create ver: 0, id: '2.0', method: 'set', args: ['color', 'red']
      @store._commit txnOne, (err) ->
        expect(err).to.be.null()
      @store._commit txnTwo, (err) ->
        expect(err).to.eql 'conflict'
        done()

    it 'different-client, same-path, sequential transaction should succeed', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create ver: 1, id: '2.0', method: 'set', args: ['color', 'red']
      @store._commit txnOne, (err) ->
        expect(err).to.be.null()
      @store._commit txnTwo, (err) ->
        expect(err).to.be.null()
        done()

    it 'same-client, same-path transaction should succeed in order', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create ver: 0, id: '1.1', method: 'set', args: ['color', 'red']
      @store._commit txnOne, (err) ->
        expect(err).to.be.null()
      @store._commit txnTwo, (err) ->
        expect(err).to.be.null()
        done()

    it 'same-client, same-path store transaction should fail in order', (done) ->
      txnOne = transaction.create ver: 0, id: '#1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create ver: 0, id: '#1.1', method: 'set', args: ['color', 'red']
      @store._commit txnOne, (err) ->
        expect(err).to.be.null()
      @store._commit txnTwo, (err) ->
        expect(err).to.eql 'conflict'
        done()

    it 'same-client, same-path transaction should fail out of order', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create ver: 0, id: '1.1', method: 'set', args: ['color', 'red']
      @store._commit txnTwo, (err) ->
        expect(err).to.be.null()
      @store._commit txnOne, (err) ->
        expect(err).to.eql 'conflict'
        done()

    it 'setting a child path should conflict', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['colors', ['green']]
      txnTwo = transaction.create ver: 0, id: '2.0', method: 'set', args: ['colors.0', 'red']
      @store._commit txnOne, (err) ->
        expect(err).to.be.null()
      @store._commit txnTwo, (err) ->
        expect(err).to.eql 'conflict'
        done()

    it 'setting a parent path should conflict', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['colors', ['green']]
      txnTwo = transaction.create ver: 0, id: '2.0', method: 'set', args: ['colors.0', 'red']
      @store._commit txnTwo, (err) ->
        expect(err).to.be.null()
      @store._commit txnOne, (err) ->
        expect(err).to.eql 'conflict'
        done()

    it 'sending a duplicate transaction should be detected', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = txnOne.slice()
      @store._commit txnOne, (err) ->
        expect(err).to.be.null()
      @store._commit txnTwo, (err) ->
        expect(err).to.eql 'duplicate'
        done()

    it 'a conflicting transaction with ver of null or undefined should succeed', (done) ->
      txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
      txnTwo = transaction.create ver: null, id: '2.0', method: 'set', args: ['color', 'red']
      txnThree = transaction.create ver: undefined, id: '3.0', method: 'set', args: ['color', 'blue']
      @store._commit txnOne, (err) ->
        expect(err).to.be.null()
      @store._commit txnTwo, (err) ->
        expect(err).to.be.null()
      @store._commit txnThree, (err) ->
        expect(err).to.be.null()
        done()
