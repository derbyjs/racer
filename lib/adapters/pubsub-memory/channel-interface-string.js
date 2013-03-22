var pathRegExp = require('../../path').regExp
  , hasKeys    = require('../../util').hasKeys;

module.exports = createStringInterface;

function createStringInterface(pubSub) {
  return new StringInterface(pubSub);
}

function StringForwardIndex() {}
function StringReverseIndex() {}

function StringInterface(pubSub) {
  this.pubSub = pubSub;
  // forwardIndex comes in handy for efficient publish
  // string -> (subscriberId -> RegExp)
  this.forwardIndex = new StringForwardIndex;
  // reverseIndex comes in handy for efficient cleanup
  // in unsubscribe
  // subscriberId -> (string -> true)
  this.reverseIndex = new StringReverseIndex;
}

function SubscriberMap() {}
function StringMap() {}

StringInterface.prototype.subscribe = function (subscriberId, str, ackCb) {
  var subscriberMap = this.forwardIndex[str] ||
    (this.forwardIndex[str] = new SubscriberMap);
  subscriberMap[subscriberId] = true;

  var stringMap = this.reverseIndex[subscriberId] ||
    (this.reverseIndex[subscriberId] = new StringMap);
  stringMap[str] = true;

  if (ackCb) ackCb(null);
};

StringInterface.prototype.publish = function (msg) {
  var type = msg.type
    , params = msg.params
    , subscribers = this.forwardIndex[params.channel];

  if (!subscribers) return;

  switch (type) {
    case 'direct':
      return emitAll('direct', params.data, subscribers, this.pubSub);
    case 'txn':
      return emitAll('txn', params.data, subscribers, this.pubSub);
    case 'addDoc':
      return emitAll('addDoc', params, subscribers, this.pubSub);
    case 'rmDoc':
      return emitAll('rmDoc', params, subscribers, this.pubSub);
  }
};

StringInterface.prototype.unsubscribe = function (subscriberId, str, ackCb) {
  var subscribers;

  if (typeof str !== 'string') {
    // Detects fn signature: unsubscribe(subscriberId, ackCb)
    // This fn sig means unsubscribe the subscriberId from everything
    ackCb = str;

    // Clean up forward index
    for (var str in this.reverseIndex[subscriberId]) {
      gcIndex(this.forwardIndex, str, subscriberId);
    }

    // Clean up reverse index
    delete this.reverseIndex[subscriberId];
  } else {
    gcIndex(this.reverseIndex, subscriberId, str);
    gcIndex(this.forwardIndex, str, subscriberId);
  }

  if (ackCb) ackCb(null);
};

StringInterface.prototype.hasSubscriptions = function (subscriberId) {
  return subscriberId in this.reverseIndex;
};

StringInterface.prototype.subscribedTo = function (subscriberId, str) {
  var strings = this.reverseIndex[subscriberId];
  if (!strings) return false;
  return str in strings;
};

// Clean up an index
function gcIndex (index, key, secondaryKey) {
  var entities = index[key];
  if (!entities) return;
  delete entities[secondaryKey];
  if (!hasKeys(entities)) delete index[key];
}

function emitAll (type, msg, subscribers, pubSub) {
  for (var subscriberId in subscribers) {
    pubSub.emit(type, subscriberId, msg);
  }
}
