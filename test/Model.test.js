var BrowserSocketMock, EventEmitter, Model, ServerClientMock, ServerSocketMock, assert, model, util, wrapTest, _;
wrapTest = require('./util').wrapTest;
assert = require('assert');
util = require('util');
EventEmitter = require('events').EventEmitter;
_ = require('../lib/util');
Model = require('../lib/Model');
model = function(environment) {
  _.onServer = environment === 'server';
  return new Model();
};
ServerSocketMock = function() {
  var clients, self;
  self = this;
  clients = this._clients = [];
  self.on('connection', function(client) {
    clients.push(client.browserSocket);
    return client._serverSocket = self;
  });
  return self.broadcast = function(message) {
    return clients.forEach(function(client) {
      return client.emit('message', message);
    });
  };
};
util.inherits(ServerSocketMock, EventEmitter);
ServerClientMock = function(browserSocket) {
  var self;
  self = this;
  self.browserSocket = browserSocket;
  return self.broadcast = function(message) {
    return self._serverSocket._clients.forEach(function(client) {
      if (browserSocket !== client) {
        return client.emit('message', message);
      }
    });
  };
};
util.inherits(ServerClientMock, EventEmitter);
BrowserSocketMock = function() {
  var self, serverClient;
  self = this;
  serverClient = new ServerClientMock(self);
  self.connect = function() {
    return serverSocket.emit('connection', serverClient);
  };
  return self.send = function(message) {
    return serverClient.emit('message', message);
  };
};
util.inherits(BrowserSocketMock, EventEmitter);
module.exports = {
  'test Model server and browser models sync': function() {
    var browserModel1, browserModel2, browserSocket1, browserSocket2, serverModel, serverSocket;
    serverModel = model('server');
    browserModel1 = model('browser');
    browserModel2 = model('browser');
    serverSocket = new ServerSocketMock();
    browserSocket1 = new BrowserSocketMock();
    browserSocket2 = new BrowserSocketMock();
    serverModel._setSocket(serverSocket);
    browserModel1._setSocket(browserSocket1);
    browserModel2._setSocket(browserSocket2);
    serverModel.set('color', 'red');
    serverModel.get().should.eql({
      color: 'red'
    });
    browserModel1.get().should.eql({
      color: 'red'
    });
    return browserModel2.get().should.eql({
      color: 'red'
    });
  }
};