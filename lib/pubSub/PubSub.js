var EventEmitter = require('events').EventEmitter
  , finishAfter = require('../util/async').finishAfter
  , isPattern = require('../path').isPattern

module.exports = PubSub;

function PubSub () {
  EventEmitter.call(this);
  var channelTypes = this._channelTypes = {
    pattern: function (x) {
      return (typeof x === 'string') && isPattern(x);
    }
  , prefix: function (x) {
      return typeof x === 'string';
    }
  , string: function (x) {
      return typeof x === 'string';
    }
  , query: function (x) {
      return x.constructor === Object;
    }
  };

  // Create scoped PubSub shortcuts for only publishing to a single channel type
  for (var chanType in channelTypes) {
    var descriptor = { value: {}};
    descriptor.value[chanType] = channelTypes[chanType];
    this[chanType] = Object.create(this, {
      _channelTypes: descriptor
    });
  }
}

PubSub.prototype.__proto__ = EventEmitter.prototype;

PubSub.prototype.subscribe = function subscribe (subscriberId, channels, cb) {
  var numChannels = channels.length;
  if (numChannels > 1) {
    cb = finishAfter(numChannels, cb);
  }
  for (var i = numChannels; i--; ) {
    var channel = channels[i]
      , type = this._channelType(channel);
    if (! type) {
      throw new Error('Channel ' + channel + ' does not match a channel type.');
    }
    type.subscribe(subscriberId, channel, cb);
  }
  return this;
};

PubSub.prototype.publish = function publish (msg, meta) {
  var channelTypes = this._channelTypes;
  for (var typeName in channelTypes) {
    var type = channelTypes[typeName];
    type.publish(msg, meta);
  }
  return this;
};

PubSub.prototype.unsubscribe = function unsubscribe (subscriberId, channels, cb) {
  var numChannels = channels && channels.length
    , channelTypes = this._channelTypes
    , type;
  if (!numChannels) {
    for (var typeName in channelTypes) {
      type = channelTypes[typeName];
      type.unsubscribe(subscriberId, cb);
    }
    return this;
  }

  if (numChannels > 1) {
    cb = finishAfter(numChannels, cb);
  }
  for (var i = numChannels; i--; ) {
    var channel = channels[i];
    type = this._channelType(channel);
    if (! type) {
      throw new Error('Channel ' + channel + ' does not match a channel type.');
    }
    type.unsubscribe(subscriberId, channel, cb);
  }
  return this;
};

PubSub.prototype.hasSubscriptions = function hasSubscriptions (subscriberId) {
  var channelTypes = this._channelTypes;
  for (var typeName in channelTypes) {
    var type = channelTypes[typeName];
    if (type.hasSubscriptions(subscriberId)) {
      return true;
    }
  }
  return false;
};

PubSub.prototype.subscribedTo = function subscribedTo (subscriberId, channel) {
  return this._channelType(channel).subscribedTo(subscriberId, channel);
};

/**
 * This merges `_interface` into the given channel named `channelType`
 *
 * @param {String} channelType
 * @param {Object} _interface maps method names to functions
 * @api protected
 */
PubSub.prototype.addChannelInterface = function addChannelInterface (channelType, _interface) {
  var type = this._channelTypes[channelType];
  for (var name in _interface) {
    type[name] = _interface[name];
  }
};

PubSub.prototype._channelType = function _channelType (x) {
  var channelTypes = this._channelTypes;
  for (var typeName in channelTypes) {
    var type = channelTypes[typeName];
    if (type(x)) return type;
  }
  return;
};

PubSub.prototype.disconnect = function disconnect () {
  this.emit('disconnect');
};
