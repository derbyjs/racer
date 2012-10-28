var filterMixin = require('./filter.Model');

exports = module.exports = plugin;
exports.decorate = 'racer';
exports.useWith = { server: true, browser: true };

function plugin (racer) {
  racer.mixin(filterMixin);
}
