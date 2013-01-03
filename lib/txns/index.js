// ## `txns` is for *transactions*.
//
// This is a racer plugin which mixins transaction handling methods into a
// Model (on both server and client) and to a Store (only on server) klasses.
//
var mixinModel = require('./txns.Model')
  , mixinStore = __dirname + '/txns.Store';

exports = module.exports = plugin;

exports.useWith = { server: true, browser: true };
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel, mixinStore);
}
