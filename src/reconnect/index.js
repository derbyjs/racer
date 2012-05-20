var mixinModel = require('./reconnect.Model');

exports = module.exports = plugin;
exports.useWith = {server: true, browser: true};
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel);
};
