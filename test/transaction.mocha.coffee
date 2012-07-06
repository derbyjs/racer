{expect} = require './util'
transaction = require '../lib/transaction.server'

describe 'transaction', ->
  # Property getters

  it 'test transaction.getVer', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getVer txn).to.eql 2

  it 'test transaction.getId', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getId txn).to.eql '4.0'

  it 'test transaction.getMethod', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getMethod txn).to.eql 'set'

  it 'test transaction.getArgs', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getArgs txn).to.eql ['count', 1]

  it 'test transaction.getPath', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getPath txn).to.eql 'count'

  it 'test transaction.getContext', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1], context: 'inception'
    expect(transaction.getContext txn).to.equal 'inception'

  it 'test transaction.ops', ->
    compoundTxn = transaction.create ver: 3, id: '4.1', ops: [transaction.op.create(method: 'set', args: ['count', 1])]
    expect(transaction.ops compoundTxn).to.eql [transaction.op.create(method: 'set', args: ['count', 1])]

  it 'test transaction.op.getMethod', ->
    op = transaction.op.create method: 'set', args: ['count', 1]
    expect(transaction.op.getMethod op).to.equal 'set'

  it 'test transaction.op.getArgs', ->
    op = transaction.op.create method: 'set', args: ['count', 1]
    expect(transaction.op.getArgs op).to.eql ['count', 1]

  # Property setters

  it 'test transaction.setVer', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getVer txn).to.equal 2
    transaction.setVer txn, 3
    expect(transaction.getVer txn).to.equal 3

  it 'test transaction.setId ', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getId txn).to.equal '4.0'
    transaction.setId txn, '4.1'
    expect(transaction.getId txn).to.equal '4.1'

  it 'test transaction.setMethod', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getMethod txn).to.equal 'set'
    transaction.setMethod txn, 'del'
    expect(transaction.getMethod txn).to.equal 'del'

  it 'test transaction.getArgs setter', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getArgs txn).to.eql ['count', 1]
    transaction.setArgs txn, ['count', 9]
    expect(transaction.getArgs txn).to.eql ['count', 9]

  it 'test transaction.setPath', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getPath txn).to.equal 'count'
    transaction.setPath txn, 'age'
    expect(transaction.getPath txn).to.equal 'age'

  it 'test transaction.setContext', ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1], context: 'inception'
    expect(transaction.getContext txn).to.equal 'inception'
    transaction.setContext txn, 'TDKR'
    expect(transaction.getContext txn).to.equal 'TDKR'

  it 'test transaction.ops setter', ->
    firstOps = [transaction.op.create(method: 'set', args: ['count', 1])]
    txn = transaction.create ver: 3, id: '4.1', ops: firstOps
    expect(transaction.ops txn).to.eql firstOps
    secondOps = [transaction.op.create(method: 'push', args: ['a', 'b'])]
    transaction.ops txn, secondOps
    expect(transaction.ops txn).to.eql secondOps

  it 'test transaction.op.setMethod', ->
    op = transaction.op.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.op.getMethod op).to.equal 'set'
    transaction.op.setMethod op, 'del'
    expect(transaction.op.getMethod op).to.equal 'del'

  it 'test transaction.op.setArgs', ->
    op = transaction.op.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.op.getArgs op).to.eql ['count', 1]
    transaction.op.setArgs op, ['count', 2]
    expect(transaction.op.getArgs op).to.eql ['count', 2]

  '''transaction.compound should return true if the txn
  has several ops''': ->
    txn = transaction.create ver: 3, id: '4.1', ops: [transaction.op.create(method: 'set', args: ['count', 1])]
    expect(transaction.isCompound txn).to.be.true

  '''transaction.compound should return false if the txn
  has only one op''': ->
    txn = transaction.create ver: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.isCompound txn).to.be.false

  # Evaluating (but not applying) transactions

  # Applying transactions

  # Path Conflict Detection

  it 'paths where neither is a sub-path of the other should not conflict', ->
    expect(transaction.pathConflict 'abc', 'def').to.be.false
    expect(transaction.pathConflict 'def', 'abc').to.be.false
    expect(transaction.pathConflict 'abc.de', 'abc.def').to.be.false
    expect(transaction.pathConflict 'abc.def', 'abc.de').to.be.false

  it 'paths where one is a sub-path of the other should conflict', ->
    expect(transaction.pathConflict 'abc', 'abc.def').to.equal 'parent'
    expect(transaction.pathConflict 'abc.def', 'abc').to.equal 'child'
    expect(transaction.pathConflict 'abc', 'abc').to.equal 'equal'

  # Transaction Conflict Detection

  it 'test conflict detection between transactions', ->
    txn0 = transaction.create ver: 0, id: '1.0', method: 'set', args: ['count', 1]
    txn1 = transaction.create ver: 0, id: '1.0', method: 'set', args: ['count', 1]
    txn2 = transaction.create ver: 0, id: '0.0', method: 'set', args: ['count', 0]
    txn3 = transaction.create ver: 0, id: '0.0', method: 'del', args: ['count', 1]
    txn4 = transaction.create ver: 0, id: '0.0', method: 'set', args: ['count', 1, 0]
    txn5 = transaction.create ver: 0, id: '0.1', method: 'set', args: ['count', 1]
    txn6 = transaction.create ver: 0, id: '0.1', method: 'set', args: ['name', 'drago']

    txn2s = transaction.create ver: 0, id: '#0.0', method: 'set', args: ['count', 1]
    txn5s = transaction.create ver: 0, id: '#0.1', method: 'set', args: ['count', 1]

    txn7 = transaction.create ver: 0, id: '1.0', method: 'set', args: ['obj.nested', 0]
    txn8 = transaction.create ver: 0, id: '2.0', method: 'set', args: ['obj.nested.a', 0]

    expect(transaction.conflict txn1, txn2).to.eql 'conflict' # Different arguments
    expect(transaction.conflict txn1, txn3).to.eql 'conflict' # Different method
    expect(transaction.conflict txn1, txn4).to.eql 'conflict' # Different number of arguments

    expect(transaction.conflict txn2, txn5).to.eql 'conflict' # Same client, wrong order
    expect(transaction.conflict txn5, txn2).to.be.false # Same client, correct order
    expect(transaction.conflict txn2s, txn5s).to.eql 'conflict' # Same store, wrong order
    expect(transaction.conflict txn5s, txn2s).to.eql 'conflict' # Same store, correct order

    expect(transaction.conflict txn1, txn6).to.be.false # Non-conflicting paths

    expect(transaction.conflict txn7, txn8).to.eql 'conflict' # Conflicting nested paths
    expect(transaction.conflict txn8, txn7).to.eql 'conflict' # Conflicting nested paths

    expect(transaction.conflict txn0, txn1).to.eql 'duplicate' # Same transaction ID
