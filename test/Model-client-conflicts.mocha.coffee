transaction = require '../src/transaction'
Model = require '../src/Model'
should = require 'should'
{calls} = require './util'
{mockSocketEcho, mockSocketModel} = require './util/model'

mirrorTest = (done, callback) ->
  mirror = new Model
  [model, sockets] = mockSocketEcho 0, true
  emitted = 0
  model.on 'mutator', (method, path, {0: args}) ->
    # console.log method, args
    emitted++
    mirror[method] args...
  [remoteModel] = mockSocketModel 1, 'txn', (txn) ->
    sockets._queue txn.slice()

  callback model, remoteModel

  process.nextTick ->
    model.socket._connect()
  setTimeout ->
    emitted.should.be.above 1
    mirror.get().should.specEql model.get()
    done()
  , 10

describe 'Model client conflicts', ->

  it 'mock should support synching txns on connect', (done) ->
    [model, sockets] = mockSocketEcho 0, true
    model.set 'name', 'John'
    sockets._queue transaction.create
      id: '1.0', method: 'set', args: ['color', 'green']

    model.socket._connect()
    setTimeout ->
      model.get().should.eql
        color: 'green'
        name: 'John'
      done()
    , 10

  it 'conflicting txn from server should be applied first', (done) ->
    [model, sockets] = mockSocketEcho 0, true
    model.set 'name', 'John'
    sockets._queue transaction.create
      id: '1.0', method: 'set', args: ['name', 'Sue']

    model.socket._connect()
    setTimeout ->
      model.get().should.eql name: 'John'
      done()
    , 10

  it 'should detect path conflicts', ->
    # Paths conflict if equal or pathA is a sub-path of pathB
    transaction.clientPathConflict('abc', 'abc').should.be.true
    transaction.clientPathConflict('abc.def', 'abc').should.be.true
    transaction.clientPathConflict('abc', 'abc.def').should.be.false
    transaction.clientPathConflict('abc', 'def').should.be.false
    transaction.clientPathConflict('def', 'abc').should.be.false
    transaction.clientPathConflict('abc.de', 'abc.def').should.be.false
    transaction.clientPathConflict('abc.def', 'abc.de').should.be.false

  it 'set on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.set 'name', 'John'
      model.set 'name', 'Sue'

  it 'set on sub-path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.set 'user.name', 'John'
      model.set 'user', {}

  it 'set and del on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.del 'name'
      model.set 'name', 'John'

  it 'set and push on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', 'a'
      model.set 'items', []

  # it 'pushes on same path', (done) ->
  #   mirrorTest done, (model, remote) ->
  #     remote.push 'items', 'a', 'b', 'c'
  #     remote.push 'items', 'd'
  #     model.push 'items', 'x', 'y', 'z'
  #     model.push 'items', 'm', 'n'

  # it 'unshifts on same path', (done) ->
  #   mirrorTest done, (model, remote) ->
  #     remote.unshift 'items', 'a', 'b', 'c'
  #     remote.unshift 'items', 'd'
  #     model.unshift 'items', 'x', 'y', 'z'
  #     model.unshift 'items', 'm', 'n'

  # it 'inserts on same path', (done) ->
  #   mirrorTest done, (model, remote) ->
  #     remote.insert 'items', 0, 'a', 'b', 'c'
  #     remote.insert 'items', 1, 'd'
  #     model.insert 'items', 0, 'x', 'y', 'z'
  #     model.insert 'items', 3, 'm', 'n'

  # it 'push & pop on same path', (done) ->
  #   mirrorTest done, (model, remote) ->
  #     remote.push 'items', 'a', 'b', 'c'
  #     # remote.pop 'items'
  #     model.push 'items', 'x'
  #     model.pop 'items'
