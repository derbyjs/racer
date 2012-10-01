var patternInterface = require('./channel-interface-pattern');

module.exports = prefixInterface;

function prefixInterface (pubSub) {
  var patternApi = patternInterface(pubSub);
  return {
    subscribe: function (subscriberId, prefix, ackCb) {
      return patternApi.subscribe(subscriberId, prefix, ackCb);
    }

  , publish: function (msg) {
      return patternApi.publish(msg);
    }

  , unsubscribe: function (subscriberId, prefix, ackCb) {
      return patternApi.unsubscribe(subscriberId, prefix, ackCb);
    }

  , hasSubscriptions: function (subscriberId) {
      return patternApi.hasSubscriptions(subscriberId);
    }

  , subscribedTo: function (subscriberId, prefix) {
      return patternApi.subscribedTo(subscriberId, prefix);
    }
  };
}
