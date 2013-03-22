var patternInterface = require('./channel-interface-pattern')
  , stringInterface = require('./channel-interface-string')
  , queryInterface = require('./channel-interface-query');

exports = module.exports = plugin;
exports.useWith = { server: true, browser: false };
exports.decorate = 'racer';

function plugin (racer, opts) {
  opts || (opts = {});
  racer.mixin({
    type: 'Store'
  , events: {
      init: function (store) {
        var pubSub = store._pubSub;
        pubSub.addChannelInterface('pattern', patternInterface(pubSub));
        pubSub.addChannelInterface('prefix', patternInterface(pubSub));
        pubSub.addChannelInterface('string', stringInterface(pubSub));
        pubSub.addChannelInterface('query', queryInterface(pubSub, store));
      }
    }
  });
}
