exports = module.exports = function (racer) {
  racer.registerAdapter('clientId', 'Mongo', ClientIdMongo);
};

exports.useWith = {server: true, browser: false};
exports.decorate = 'racer';

function ClientIdMongo (options) {
  this._options = options;
}

ClientIdMongo.prototype.generateFn = function () {
  var ObjectID = this._options.mongo.BSONPure.ObjectID;
  return function (cb) {
    try {
      var guid = (new ObjectID).toString();
      cb(null, guid);
    } catch (e) {
      cb(e);
    }
  };
};
