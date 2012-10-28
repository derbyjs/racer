var mixinModel = require('./pattern.Model')
  , mixinStore = __dirname + '/pattern.Store'
  ;

exports = module.exports = plugin;

exports.useWith = {server: true, browser: true};
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel, mixinStore);
}
