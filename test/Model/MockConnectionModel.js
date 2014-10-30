var share = require('share');
var Model = require('../../lib/Model');

module.exports = MockConnectionModel;
function MockConnectionModel() {
  Model.apply(this, arguments);
}
MockConnectionModel.prototype = Object.create(Model.prototype);

MockConnectionModel.prototype.createConnection = function() {
  var socketMock;
  socketMock = {
    send: function(message) {},
    close: function() {},
    onmessage: function() {},
    onclose: function() {},
    onerror: function() {},
    onopen: function() {},
    onconnecting: function() {}
  };
  this.root.shareConnection = new share.client.Connection(socketMock);
};
