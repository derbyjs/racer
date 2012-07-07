var mixinModel = require('./context.Model');

exports = module.exports = plugin;

exports.useWith = { server: true, browser: false };

exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel);
}
