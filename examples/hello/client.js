var racer = require('../../lib/racer');

racer.on('ready', function(model) {
  window.model = model;
  model._subscribeDoc('users', 'seph', function() {

  });
});

racer.init(window.RACER_BUNDLE);
