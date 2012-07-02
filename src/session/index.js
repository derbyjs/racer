var mixinStore = require('./session.Store');

exports = module.exports = plugin;

exports.decorate = 'racer';
exports.useWith = { server: true, browser: false };

function plugin (racer) {
  racer.mixin(mixinStore);
}
