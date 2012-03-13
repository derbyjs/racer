{expect} = require './util'
transaction = require '../src/transaction.server'

describe 'transaction', ->
  # Property getters

  it 'test transaction.base', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.base txn).to.eql 2

  it 'test transaction.getId', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getId txn).to.eql '4.0'

  it 'test transaction.method', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.method txn).to.eql 'set'

  it 'test transaction.args', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.args txn).to.eql ['count', 1]

  it 'test transaction.path', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.path txn).to.eql 'count'

  it 'test transaction.ops', ->
    compoundTxn = transaction.create base: 3, id: '4.1', ops: [transaction.op.create(method: 'set', args: ['count', 1])]
    expect(transaction.ops compoundTxn).to.eql [transaction.op.create(method: 'set', args: ['count', 1])]

  it 'test transaction.op.method', ->
    op = transaction.op.create method: 'set', args: ['count', 1]
    expect(transaction.op.method op).to.equal 'set'

  it 'test transaction.op.args', ->
    op = transaction.op.create method: 'set', args: ['count', 1]
    expect(transaction.op.args op).to.eql ['count', 1]

  # Property setters

  it 'test transaction.base setter', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.base txn).to.equal 2
    transaction.base txn, 3
    expect(transaction.base txn).to.equal 3

  it 'test transaction.setId ', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.getId txn).to.equal '4.0'
    transaction.setId txn, '4.1'
    expect(transaction.getId txn).to.equal '4.1'

  it 'test transaction.method setter', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.method txn).to.equal 'set'
    transaction.method txn, 'del'
    expect(transaction.method txn).to.equal 'del'

  it 'test transaction.args setter', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.args txn).to.eql ['count', 1]
    transaction.args txn, ['count', 9]
    expect(transaction.args txn).to.eql ['count', 9]

  it 'test transaction.path setter', ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.path txn).to.equal 'count'
    transaction.path txn, 'age'
    expect(transaction.path txn).to.equal 'age'

  it 'test transaction.ops setter', ->
    firstOps = [transaction.op.create(method: 'set', args: ['count', 1])]
    txn = transaction.create base: 3, id: '4.1', ops: firstOps
    expect(transaction.ops txn).to.eql firstOps
    secondOps = [transaction.op.create(method: 'push', args: ['a', 'b'])]
    transaction.ops txn, secondOps
    expect(transaction.ops txn).to.eql secondOps

  it 'test transaction.op.method setter', ->
    op = transaction.op.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.op.method op).to.equal 'set'
    transaction.op.method op, 'del'
    expect(transaction.op.method op).to.equal 'del'

  it 'test transaction.op.args setter', ->
    op = transaction.op.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
    expect(transaction.op.args op).to.eql ['count', 1]
    transaction.op.args op, ['count', 2]
    expect(transaction.op.args op).to.eql ['count', 2]

  '''transaction.compound should return true if the txn
  has several ops''': ->
    txn = transaction.create base: 3, id: '4.1', ops: [transaction.op.create(method: 'set', args: ['count', 1])]
    expect(transaction.isCompound txn).to.be.true

  '''transaction.compound should return false if the txn
  has only one op''': ->
    txn = transaction.create base: 2, id: '4.0', method: 'set', args: ['count', 1]
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
    txn0 = transaction.create base: 0, id: '1.0', method: 'set', args: ['count', 1]
    txn1 = transaction.create base: 0, id: '1.0', method: 'set', args: ['count', 1]
    txn2 = transaction.create base: 0, id: '0.0', method: 'set', args: ['count', 0]
    txn3 = transaction.create base: 0, id: '0.0', method: 'del', args: ['count', 1]
    txn4 = transaction.create base: 0, id: '0.0', method: 'set', args: ['count', 1, 0]
    txn5 = transaction.create base: 0, id: '0.1', method: 'set', args: ['count', 1]
    txn6 = transaction.create base: 0, id: '0.1', method: 'set', args: ['name', 'drago']

    txn2s = transaction.create base: 0, id: '#0.0', method: 'set', args: ['count', 1]
    txn5s = transaction.create base: 0, id: '#0.1', method: 'set', args: ['count', 1]

    txn7 = transaction.create base: 0, id: '1.0', method: 'set', args: ['obj.nested', 0]
    txn8 = transaction.create base: 0, id: '2.0', method: 'set', args: ['obj.nested.a', 0]

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
