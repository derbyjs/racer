var modelMixin = require('./query.Model')
  , storeMixin = __dirname + '/query.Store';

exports = module.exports = plugin;

exports.useWith = { server: true, browser: true };
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(modelMixin, storeMixin);
};
