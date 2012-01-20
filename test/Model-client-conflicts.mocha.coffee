transaction = require '../src/transaction'
Model = require '../src/Model'
should = require 'should'
{calls} = require './util'
{mockSocketEcho} = require './util/model'

describe 'Model client conflicts', ->

  it 'test client set roundtrip with server echoing transaction', (done) ->
    [model, sockets] = mockSocketEcho 0, true
    model.socket.on 'txn', (txn, num) ->
      model.get('color').should.eql 'green'
      done()

    model.socket._connect()

    sockets.emit 'txn', transaction.create
      base: 1, id: '1.0', method: 'set', args: ['color', 'green']

    # model.socket._connect()
