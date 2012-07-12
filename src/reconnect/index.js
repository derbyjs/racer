var mixinModel = require('./reconnect.Model')
  , mixinStore = __dirname + '/reconnect.Store'

exports = module.exports = plugin;
exports.useWith = {server: true, browser: true};
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel, mixinStore);
};
