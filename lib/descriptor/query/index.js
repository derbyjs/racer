var mixinModel = require('./query.Model')
  , mixinStore = __dirname + '/query.Store'
  ;

exports = module.exports = plugin;

exports.useWith = {server: true, browser: true};
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel, mixinStore);
}
