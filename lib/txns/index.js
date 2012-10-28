var mixinModel = require('./txns.Model')
  , mixinStore = __dirname + '/txns.Store';

exports = module.exports = plugin;

exports.useWith = { server: true, browser: true };
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel, mixinStore);
}
