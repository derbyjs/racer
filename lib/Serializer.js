/**
 * Given a stream of out of order messages and an index, Serializer figures out
 * what messages to handle immediately and what messages to buffer and defer
 * handling until later, if the incoming message has to wait first for another
 * message.
 */

var DEFAULT_EXPIRY = 1000; // milliseconds

// TODO Respect Single Responsibility -- place waiter code elsewhere
module.exports = Serializer;

function Serializer (options) {
  this.withEach = options.withEach;
  var onTimeout = this.onTimeout = options.onTimeout
    , expiry = this.expiry = options.expiry;

  if (onTimeout && ! expiry) {
    this.expiry = DEFAULT_EXPIRY;
  }

  // Maps future indexes -> messages
  this._pending = {};

  var init = options.init;
  // Corresponds to ver in Store and txnNum in Model
  this._index = (init != null)
              ? init
              : 1;
}

Serializer.prototype = {
  _setWaiter: function () {
    if (!this.onTimeout || this._waiter) return;
    var self = this;
    this._waiter  = setTimeout( function () {
      self.onTimeout();
      self._clearWaiter();
    }, this.expiry);
  }

, _clearWaiter: function () {
    if (! this.onTimeout) return;
    if (this._waiter) {
      clearTimeout(this._waiter);
      delete this._waiter;
    }
  }

, add: function (msg, msgIndex, arg) {
    // Cache this message to be applied later if it is not the next index
    if (msgIndex > this._index) {
      this._pending[msgIndex] = msg;
      this._setWaiter();
      return true;
    }

    // Ignore this message if it is older than the current index
    if (msgIndex < this._index) return false;

    // Otherwise apply it immediately
    this.withEach(msg, this._index++, arg);
    this._clearWaiter();

    // And apply any messages that were waiting for txn
    var pending = this._pending;
    while (msg = pending[this._index]) {
      this.withEach(msg, this._index, arg);
      delete pending[this._index++];
    }
    return true;
  }

, setIndex: function (index) {
    this._index = index;
  }

, clearPending: function () {
    var index = this._index
      , pending = this._pending;
    for (var i in pending) {
      if (i < index) delete pending[i];
    }
  }
};
