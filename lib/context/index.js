var mixinModel = require('./context.Model')
  , mixinStore = __dirname + '/context.Store'
  ;

exports = module.exports = plugin;

exports.useWith = {server: true, browser: true};

exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel, mixinStore);
}
