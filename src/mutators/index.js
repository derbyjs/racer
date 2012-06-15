var mixinModel = require('./mutators.Model')
  , mixinStore = __dirname + '/mutators.Store';

exports = module.exports = plugin;

function plugin (racer) {
  racer.mixin(mixinModel, mixinStore);
}

exports.useWith = { server: true, browser: true };
exports.decorate = 'racer';
