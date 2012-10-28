var uuid = require('node-uuid');

exports = module.exports = plugin;
exports.useWith = { server: false, browser: true };
exports.decorate = 'racer';

function plugin (racer) {
  racer.registerAdapter('clientId', 'Rfc4122_v4', ClientIdRfc4122_v4);
}

function ClientIdRfc4122_v4 (options) {
  this._options = options;
}

ClientIdRfc4122_v4.prototype.generateFn = function () {
  var _options = this._options
    , options = _options.options
    , buffer  = _options.buffer
    , offset  = _options.offset
    ;

  return function (cb) {
    var clientId = uuid.v4(options, buffer, offset);
    cb(null, clientId);
  };
};
