transaction = require '../src/transaction'
Model = require '../src/Model'
should = require 'should'
{calls} = require './util'
{mockSocketEcho} = require './util/model'

mirrored = ->
  mirror = new Model
  [model, sockets] = mockSocketEcho 0, true
  model.on 'mutator', (method, path, {0: args}) ->
    mirror[method] args...
  return [model, sockets, mirror]

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

  it 'set on same path', (done) ->
    [model, sockets, mirror] = mirrored()
    model.set 'name', 'John'
    sockets._queue transaction.create
      id: '1.0', method: 'set', args: ['name', 'Sue']

    model.socket._connect()
    setTimeout ->
      mirror.get().should.specEql model.get()
    , 10

