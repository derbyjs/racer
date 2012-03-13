{expect} = require '../util'
transaction = require '../../lib/transaction'

module.exports = (getStore) ->

  it 'different-client, different-path, simultaneous transaction should succeed', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create ver: 0, id: '2.0', method: 'set', args: ['favorite-skittle', 'red']
    getStore()._commit txnOne, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnTwo, (err) ->
      expect(err).to.be.null()
      done()

  it 'different-client, same-path, simultaneous transaction should fail', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create ver: 0, id: '2.0', method: 'set', args: ['color', 'red']
    getStore()._commit txnOne, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnTwo, (err) ->
      expect(err).to.eql 'conflict'
      done()

  it 'different-client, same-path, sequential transaction should succeed', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create ver: 1, id: '2.0', method: 'set', args: ['color', 'red']
    getStore()._commit txnOne, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnTwo, (err) ->
      expect(err).to.be.null()
      done()

  it 'same-client, same-path transaction should succeed in order', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create ver: 0, id: '1.1', method: 'set', args: ['color', 'red']
    getStore()._commit txnOne, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnTwo, (err) ->
      expect(err).to.be.null()
      done()

  it 'same-client, same-path store transaction should fail in order', (done) ->
    txnOne = transaction.create ver: 0, id: '#1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create ver: 0, id: '#1.1', method: 'set', args: ['color', 'red']
    getStore()._commit txnOne, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnTwo, (err) ->
      expect(err).to.eql 'conflict'
      done()

  it 'same-client, same-path transaction should fail out of order', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create ver: 0, id: '1.1', method: 'set', args: ['color', 'red']
    getStore()._commit txnTwo, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnOne, (err) ->
      expect(err).to.eql 'conflict'
      done()

  it 'setting a child path should conflict', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['colors', ['green']]
    txnTwo = transaction.create ver: 0, id: '2.0', method: 'set', args: ['colors.0', 'red']
    getStore()._commit txnOne, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnTwo, (err) ->
      expect(err).to.eql 'conflict'
      done()

  it 'setting a parent path should conflict', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['colors', ['green']]
    txnTwo = transaction.create ver: 0, id: '2.0', method: 'set', args: ['colors.0', 'red']
    getStore()._commit txnTwo, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnOne, (err) ->
      expect(err).to.eql 'conflict'
      done()

  it 'sending a duplicate transaction should be detected', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = txnOne.slice()
    getStore()._commit txnOne, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnTwo, (err) ->
      expect(err).to.eql 'duplicate'
      done()

  it 'a conflicting transaction with ver of null or undefined should succeed', (done) ->
    txnOne = transaction.create ver: 0, id: '1.0', method: 'set', args: ['color', 'green']
    txnTwo = transaction.create ver: null, id: '2.0', method: 'set', args: ['color', 'red']
    txnThree = transaction.create ver: undefined, id: '3.0', method: 'set', args: ['color', 'blue']
    getStore()._commit txnOne, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnTwo, (err) ->
      expect(err).to.be.null()
    getStore()._commit txnThree, (err) ->
      expect(err).to.be.null()
      done()
