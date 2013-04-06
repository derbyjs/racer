var racer = require('../../lib/racer');

racer.on('ready', function(model) {
  console.log(model);
});

racer.init(window.RACER_BUNDLE);
