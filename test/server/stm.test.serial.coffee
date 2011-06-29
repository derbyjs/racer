wrapTest = require('./util').wrapTest
newModel = require('./util/model').newModel
mocks = require './util/mocks'
ServerSocketMock = mocks.ServerSocketMock
BrowserSocketMock = mocks.BrowserSocketMock
stm = require 'server/stm'

stm.connect()
module.exports =
  setup: (done) ->
    stm.client.flushdb (err) ->
      throw err if err
      done()
  teardown: (done) ->
    stm.client.flushdb (err) ->
      throw err if err
      done()

  # compare clientIds = If same, then noconflict
  # compare paths     = If different, then noconflict
  # compare bases     = If same, then conflict
  #                     If b1 > b2, and we are considering b1

  '2 concurrent transactions from different clients and targeting the same path should callback for conflict resolution': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'color', 'red']
    stm.attempt txnOne, (err) ->
      should.strictEqual null, err
    stm.attempt txnTwo, (err) ->
      err.should.be.an.instanceof Error
      done()

  '2 concurrent transactions from different clients and targeting different paths should be applied': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '2.0', 'set', 'favorite-skittle', 'red']
    stm.attempt txnOne, (err) ->
      should.strictEqual null, err
    stm.attempt txnTwo, (err) ->
      should.strictEqual null, err
      done()

  '2 same-client transactions targetting the same path should be applied': (done) ->
    txnOne = [0, '1.0', 'set', 'color', 'green']
    txnTwo = [0, '1.1', 'set', 'color', 'red']
    stm.attempt txnOne, (err) ->
      should.strictEqual null, err
    stm.attempt txnTwo, (err) ->
      should.strictEqual null, err
      done()

  # TODO

  '2 out-of-order same-client transactions targetting the same path should be applied in the correct order': (done) ->
    done()

  'a transaction that was generated before the current base server version should callback for conflict resolution if it conflicts with a transaction in the journal that occurred at the same snapshot base version': (done) ->
    done()

  'a transaction that was generated before the current base server version should callback for conflict resolution if it conflicts with a transaction in the journal that occurred after its snapshot base version': (done) ->
    done()

  'a transaction that was generated before the current base server version should be applied if the only transactions in the journal it conflicts with are those that came before it': (done) ->
    done()

  'a transaction that was generated before the current base server version should be applied if the only transactions in the journal it conflicts with are those that came before it': (done) ->
    done()

  'finishAll': (done) ->
    stm.client.end()
    done()
  
  'test client set roundtrip with STM': wrapTest (done) ->
    serverSocket = new ServerSocketMock()
    browserSocket = new BrowserSocketMock(serverSocket)
    
    serverSocket.on 'connection', (client) ->
      client.on 'message', (message) ->
        setTimeout ->
          
          serverSocket.broadcast JSON.parse message
          model.get('color').should.eql 'green'
          done()
        , 0
    
    model = newModel 'browser'
    model._clientId = 'client0'
    model._setSocket browserSocket
    
    model.set 'color', 'green'