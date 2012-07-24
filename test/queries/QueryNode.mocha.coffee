QueryNode = require '../../lib/descriptor/query/QueryNode'
QueryBuilder = require '../../lib/descriptor/query/QueryBuilder'
transaction = require '../../lib/transaction'
{expect} = require '../util'
sinon = require 'sinon'

exports.publishArgs = publishArgs = (type, channel, data) ->
  return {
    type: type
    params:
      channel: channel
      data: data
  }

describe 'QueryNode', ->
  queryJson =
    from: 'users'
    equals:
      name: 'Brian'
    gt:
      age: 21
  qnode = new QueryNode queryJson

  it '#hash should correspond to the query hash', ->
    expect(qnode.hash).to.equal QueryBuilder.hash queryJson

  it '#channel should correspond to the channel we publish query events on', ->
    expect(qnode.channel).to.equal "$q.#{qnode.hash}"

  describe '#results(db, cb)', ->
    it 'should pass back the results in the db'

  # TODO test the actual publishing event
  describe '#shouldPublish(newDoc, oldDoc, txn, store, cb)', ->

    it 'should publish an "addDoc" event when the document change should result in it being added to the query result set', ->
      callback = sinon.spy()

      txn = transaction.create
        ver: ver = 1
        id: 'txnid'
        method: 'set'
        args: ['users.1.age', 22]
      oldDoc = id: '1', name: 'Brian', age: 21
      newDoc = id: '1', name: 'Brian', age: 22

      qnode.shouldPublish newDoc, oldDoc, txn, {}, callback

      expect(callback).to.be.calledOnce()
      expect(callback.firstCall.args).to.eql [null, [['addDoc', 'users', ver, newDoc]]]
      # TODO Move the line to a new series of tests testing model.publish
      # expect(callback).to.be.calledWith publishArgs('addDoc', qnode.channel, {ns: 'users', doc: newDoc, ver: ver})

    it 'should publish "rmDoc" when the document change should result in the doc being removed from the query result set', ->
      callback = sinon.spy()

      txn = transaction.create
        ver: ver = 1
        id: 'txnid'
        method: 'set'
        args: ['users.1.age', 20]
      oldDoc = id: '1', name: 'Brian', age: 22
      newDoc = id: '1', name: 'Brian', age: 20

      qnode.shouldPublish newDoc, oldDoc, txn, {}, callback

      expect(callback).to.be.calledOnce()
      expect(callback.firstCall.args).to.eql [null, [['rmDoc', 'users', ver, newDoc, oldDoc.id]]]
      # TODO expect(pubSub.publish).to.be.calledWith publishArgs('rmDoc', qnode.channel, {ns: 'users', id: '1', ver: ver})

    it 'should publish the transaction when the document change does not influence the query result set which already contained the doc prior to mutation', ->
      callback = sinon.spy()

      txn = transaction.create
        ver: ver = 1
        id: 'txnid'
        method: 'set'
        args: ['users.1.age', 23]
      oldDoc = id: '1', name: 'Brian', age: 22
      newDoc = id: '1', name: 'Brian', age: 23

      qnode.shouldPublish newDoc, oldDoc, txn, {}, callback

      expect(callback).to.be.calledOnce()
      expect(callback.firstCall.args).to.eql [null, [['txn']]]
      # expect(pubSub.publish).to.be.calledWith publishArgs('txn', qnode.channel, txn)

    it 'should publish nothing if neither the oldDoc or the newDoc are in the result set', ->
      pubSub = publish: sinon.spy()

      txn = transaction.create
        ver: ver = 1
        id: 'txnid'
        method: 'set'
        args: ['users.1.age', 20]
      oldDoc = id: '1', name: 'Brian', age: 19
      newDoc = id: '1', name: 'Brian', age: 20

      qnode.shouldPublish newDoc, oldDoc, txn, {pubSub}

      expect(pubSub.publish).to.have.callCount(0)
