var pathRegExp = require('../../path').regExp
  , hasKeys = require('../../util').hasKeys;

module.exports = createPatternInterface;

function createPatternInterface(pubSub) {
  return new PatternInterface(pubSub);
}

function PatternForwardIndex() {}
function PatternReverseIndex() {}

function PatternInterface(pubSub) {
  this.pubSub = pubSub;
  // patternString -> {re: RegExp, subscribers: (subscriberId -> true)}
  this.forwardIndex = new PatternForwardIndex;
  // subscriberId -> (patternString -> true)
  this.reverseIndex = new PatternReverseIndex;
}

function SubscriberMap() {}
function PatternSubscribers(pattern) {
  this.re = pathRegExp(pattern);
  this.subscribers = new SubscriberMap;
}

PatternInterface.prototype.subscribe = function(subscriberId, pattern, ackCb) {
  var subscriberMap = this.reverseIndex[subscriberId] ||
    (this.reverseIndex[subscriberId] = new SubscriberMap);
  subscriberMap[pattern] = true;

  var patternSubscribers = this.forwardIndex[pattern] ||
    (this.forwardIndex[pattern] = new PatternSubscribers(pattern))
  patternSubscribers.subscribers[subscriberId] = true;

  ackCb && ackCb(null);
};

PatternInterface.prototype.publish = function(msg) {
  var type = msg.type
    , params = msg.params;
  if (type === 'txn' || type === 'ot') {
    for (var pattern in this.forwardIndex) {
      var x = this.forwardIndex[pattern]
        , re = x.re
        , subscribers = x.subscribers;
      if (! re.test(params.channel)) continue;
      for (var subscriberId in subscribers) {
        this.pubSub.emit(type, subscriberId, params.data);
      }
    }
  }
};

PatternInterface.prototype.unsubscribe = function(subscriberId, pattern, ackCb) {
  var patterns = this.reverseIndex[subscriberId];
  if (typeof pattern !== 'string') {
    ackCb = pattern;

    // Clean up forward index
    for (var _pattern_ in patterns) {
      var subscribers = this.forwardIndex[_pattern_].subscribers;
      delete subscribers[subscriberId];
      if (! hasKeys(subscribers)) {
        delete this.forwardIndex[_pattern_];
      }
    }

    // Clean up reverseIndex
    delete this.reverseIndex[subscriberId];
  } else {
    // Clean up reverseIndex
    if (! patterns) {
      // If the subscriberId was never subscribed, do nothing
      return ackCb && ackCb(null);
    }
    delete patterns[pattern];
    if (! hasKeys(patterns)) {
      delete this.reverseIndex[subscriberId];
    }

    // Clean up forward index
    var subscribers = this.forwardIndex[pattern].subscribers;
    delete subscribers[subscriberId];
    if (! hasKeys(subscribers)) {
      delete this.forwardIndex[pattern];
    }
  }

  ackCb && ackCb(null);
};

PatternInterface.prototype.hasSubscriptions = function(subscriberId) {
  return subscriberId in this.reverseIndex;
};

PatternInterface.prototype.subscribedTo = function(subscriberId, pattern) {
  var patterns = this.reverseIndex[subscriberId];
  return !!patterns && (pattern in patterns);
};
