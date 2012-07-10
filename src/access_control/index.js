var mixinStore = __dirname + '/access_control.Store';

exports = module.exports = plugin;

exports.useWith = { server: true, browser: false };

exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinStore);
}
