var pathRegExp = require('../../path').regExp
  , hasKeys = require('../../util').hasKeys;

module.exports = patternInterface;

function patternInterface (pubSub) {
  // patternString -> {re: RegExp, subscribers: (subscriberId -> true)}
  var forwardIndex = {};

  // subscriberId -> (patternString -> true)
  var reverseIndex = {};

  var intf = {};

  intf.subscribe = function (subscriberId, pattern, ackCb) {
    var hash = reverseIndex[subscriberId] || (reverseIndex[subscriberId] = {});
    hash[pattern] = true;

    var subsForPattern = forwardIndex[pattern];
    if (!subsForPattern) {
      subsForPattern = forwardIndex[pattern] = {
        re: pathRegExp(pattern)
      , subscribers: {}
      };
    }
    subsForPattern.subscribers[subscriberId] = true;
    ackCb && ackCb(null);
  };

  intf.publish = function (msg) {
    var type = msg.type
      , params = msg.params;
    if (type === 'txn' || type === 'ot') {
      for (var pattern in forwardIndex) {
        var x = forwardIndex[pattern]
          , re = x.re
          , subscribers = x.subscribers;
        if (! re.test(params.channel)) continue;
        for (var subscriberId in subscribers) {
          pubSub.emit(type, subscriberId, params.data);
        }
      }
    }
  };

  intf.unsubscribe = function (subscriberId, pattern, ackCb) {
    var patterns = reverseIndex[subscriberId];
    if (typeof pattern !== 'string') {
      ackCb = pattern;

      // Clean up forward index
      for (var _pattern_ in patterns) {
        var subscribers = forwardIndex[_pattern_].subscribers;
        delete subscribers[subscriberId];
        if (! hasKeys(subscribers)) {
          delete forwardIndex[_pattern_];
        }
      }

      // Clean up reverseIndex
      delete reverseIndex[subscriberId];
    } else {
      // Clean up reverseIndex
      if (! patterns) {
        // If the subscriberId was never subscribed, do nothing
        return ackCb && ackCb(null);
      }
      delete patterns[pattern];
      if (! hasKeys(patterns)) {
        delete reverseIndex[subscriberId];
      }

      // Clean up forward index
      var subscribers = forwardIndex[pattern].subscribers;
      delete subscribers[subscriberId];
      if (! hasKeys(subscribers)) {
        delete forwardIndex[pattern];
      }
    }

    ackCb && ackCb(null);
  };

  intf.hasSubscriptions = function (subscriberId) {
    return subscriberId in reverseIndex;
  };

  intf.subscribedTo = function (subscriberId, pattern) {
    var patterns = reverseIndex[subscriberId];
    return !!patterns && (pattern in patterns);
  };

  return intf;
}
