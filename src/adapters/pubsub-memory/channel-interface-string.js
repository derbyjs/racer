var pathRegExp = require('../../path').regExp
  , hasKeys    = require('../../util').hasKeys;

module.exports = createStringInterface;

function createStringInterface (pubSub) {
  // forwardIndex comes in handy for efficient publish
  //
  // string -> (subscriberId -> RegExp)
  var forwardIndex = {};

  // reverseIndex comes in handy for efficient cleanup
  // in unsubscribe
  //
  // subscriberId -> (string -> true)
  var reverseIndex = {};

  var intf = {};

  var self = this;

  intf.subscribe = function (subscriberId, str, ackCb) {
    var subscribers = forwardIndex[str] || (forwardIndex[str] = {});
    subscribers[subscriberId] = true;

    var strings = reverseIndex[subscriberId] || (reverseIndex[subscriberId] = {});
    strings[str] = true;

    if (ackCb) ackCb(null);
  };

  intf.publish = function (msg) {
    var type = msg.type
      , params = msg.params
      , subscribers = forwardIndex[params.channel];

    if (!subscribers) return;

    switch (type) {
      case 'direct':
        return emitAll('direct', params.data, subscribers, pubSub);
      case 'txn':
        return emitAll('txn', params.data, subscribers, pubSub);
      case 'addDoc':
        return emitAll('addDoc', params, subscribers, pubSub);
      case 'rmDoc':
        return emitAll('rmDoc', params, subscribers, pubSub);
    }
  };

  intf.unsubscribe = function (subscriberId, str, ackCb) {
    var subscribers;

    if (typeof str !== 'string') {
      // Detects fn signature: unsubscribe(subscriberId, ackCb)
      // This fn sig means unsubscribe the subscriberId from everything
      ackCb = str;

      // Clean up forward index
      for (var str in reverseIndex[subscriberId]) {
        gcIndex(forwardIndex, str, subscriberId);
      }

      // Clean up reverse index
      delete reverseIndex[subscriberId];
    } else {
      gcIndex(reverseIndex, subscriberId, str);
      gcIndex(forwardIndex, str, subscriberId);
    }

    if (ackCb) ackCb(null);
  };

  intf.hasSubscriptions = function (subscriberId) {
    return subscriberId in reverseIndex;
  };

  intf.subscribedTo = function (subscriberId, str) {
    var strings = reverseIndex[subscriberId];
    if (!strings) return false;
    return str in strings;
  };

  return intf;
}

// Clean up an index
function gcIndex (index, key, secondaryKey) {
  var entities = index[key];
  if (!entities) return;
  delete entities[secondaryKey];
  if (! hasKeys(entities)) delete index[key];
}

function emitAll (type, msg, subscribers, pubSub) {
  for (var subscriberId in subscribers) {
    pubSub.emit(type, subscriberId, msg);
  }
}
