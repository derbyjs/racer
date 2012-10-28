var mixinStore = __dirname + '/pubSub.Store';

exports = module.exports = function (racer) {
  racer.mixin(mixinStore);
};

exports.useWith = { server: false, browser: true };
exports.decorate = 'racer';
