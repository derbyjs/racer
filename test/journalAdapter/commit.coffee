{expect} = require '../util'
transaction = require '../../src/transaction'

module.exports = (getStore) ->

  it 'store._commit should apply transactions in order', (done) ->
    store = getStore()
    idIn = []
    idOut = []
    finish = ->
      expect(idOut).to.eql idIn
      done()
    for i in [0..9]
      idIn.push id = "1.#{i}"
      txn = transaction.create(base: 0, id: id, method: 'set', args: ['stuff', 0])
      store._commit txn, (err, txn) ->
        idOut.push transaction.id txn
        finish() if idOut.length is 10
