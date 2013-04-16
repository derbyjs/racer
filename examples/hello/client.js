var racer = require('../../lib/racer');

racer.on('ready', function(model) {
  window.model = model;
  model.subscribeDoc('users', 'seph', function() {
    model.set('users.seph.some.new.stuff', true)
  });
});

racer.init(window.RACER_BUNDLE);
