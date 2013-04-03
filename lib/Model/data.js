// var share = require('share');
var racer = require('../racer');
var Model = require('./index');

racer.on('Model:init', function(model) {
  model.on('message', function(message) {
    console.log('message', message);
  });
});
