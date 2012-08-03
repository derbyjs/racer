exports = module.exports = function (racer) {
  racer.registerAdapter('clientId', 'Redis', ClientIdRedis);
};

exports.useWith = {server: true, browser: true};

exports.decorate = 'racer';

function ClientIdRedis (options) {
  this._options = options;
}

ClientIdRedis.prototype.generateFn = function () {
  var redisClient = this._options.redisClient;
  return function (cb) {
    redisClient.incr('clientClock', function (err, val) {
      if (err) return cb(err);
      var clientId = val.toString(36);
      cb(null, clientId);
    });
  };
};
