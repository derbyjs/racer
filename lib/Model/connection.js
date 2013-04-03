var racer = require('../racer');
var Model = require('./index');

racer.on('Model:init', function(model) {
  var socket = new window.BCSocket('/channel');
  model.socket = socket;
  model._send = function _send(message) {
    socket.send(message);
  };
  // socket.onopen = function() {
  //   socket.send({hi: 'there'});
  // };
  socket.onmessage = function(message) {
    model.emit('message', message);
  };
});
