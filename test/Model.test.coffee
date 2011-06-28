wrapTest = require('./util').wrapTest
assert = require('assert')
util = require('util')
EventEmitter = require('events').EventEmitter
_ = require('../lib/util')
Model = require('../lib/Model')

newModel = (environment) ->
  _.onServer = environment == 'server'
  new Model()

ServerSocketMock = ->
  self = this
  clients = this._clients = []
  self.on 'connection', (client) ->
    clients.push client.browserSocket
    client._serverSocket = self
  self.broadcast = (message) ->
    clients.forEach (client) ->
      client.emit 'message', JSON.stringify message
  return
util.inherits ServerSocketMock, EventEmitter

ServerClientMock = (browserSocket) ->
  self = this
  self.browserSocket = browserSocket
  self.broadcast = (message) ->
    self._serverSocket._clients.forEach (client) ->
      if browserSocket != client
        client.emit 'message', JSON.stringify message
  return
util.inherits ServerClientMock, EventEmitter

BrowserSocketMock = (serverSocket) ->
  self = this
  serverClient = new ServerClientMock self
  self.connect = ->
    serverSocket.emit 'connection', serverClient
  self.send = (message) ->
    serverClient.emit 'message', JSON.stringify message
  return
util.inherits BrowserSocketMock, EventEmitter

module.exports =
  'test get': ->
    model = newModel 'server'
    model._data.should.eql {}
    model._data =
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model.get('color').should.eql 'green'
    model.get('info.numbers').should.eql first: 2, second: 10
    model.get().should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
  
  'test internal set': ->
    model = newModel 'server'
    model._data.should.eql {}
    
    model._setters.set 'color', 'green'
    model._data.should.eql color: 'green'
    
    model._setters.set 'info.numbers', first: 2, second: 10
    model._data.should.eql
      color: 'green'
      info:
        numbers:
          first: 2
          second: 10
    
    model._setters.set 'info', 'new'
    model._data.should.eql
      color: 'green'
      info: 'new'
  
  'test internal creation of client transactions on set': ->
    model = newModel 'browser'
    model._clientId = 'client0'
    
    model.set 'color', 'green'
    model._txns.should.eql
      'client0.0':
        op: ['set', 'color', 'green']
        base: 0
        sent: false
    model._txnQueue.should.eql ['client0.0']
    
    model.set 'count', 0
    model._txns.should.eql
      'client0.0':
        op: ['set', 'color', 'green']
        base: 0
        sent: false
      'client0.1':
        op: ['set', 'count', '0']
        base: 0
        sent: false
    model._txnQueue.should.eql ['client0.0', 'client0.1']
  
  'test client performs set on receipt of message': ->
    serverSocket = new ServerSocketMock()
    browserSocket = new BrowserSocketMock(serverSocket)
    model = newModel 'browser'
    model._setSocket browserSocket
    
    serverSocket.broadcast ['txn', [1, 'server0.0', 'set', 'color', 'green']]
    model.get('color').should.eql 'green'