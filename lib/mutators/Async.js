var transaction = require('../transaction')
  , noop = require('../util').noop;

// TODO Implement remaining methods for AsyncAtomic
// TODO Redo implementation using a macro

module.exports = Async;

function Async (options) {
  options || (options = {});
  if (options.get) this.get = options.get;
  if (options.commit) this._commit = options.commit;
  this.model = options.model;

  // Note that async operation clientIds MUST begin with '#', as this is used
  // to treat conflict detection between async and sync transactions differently
  var nextTxnId = options.nextTxnId;
  if (nextTxnId) {
    this._nextTxnId = function (callback) {
      callback(null, '#' + nextTxnId());
    };
  }
}

Async.prototype = {
  set: function (path, value, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'set'
      , args: [path, value]
      });
      // TODO When store is mutating, it should have something akin to
      // superadmin rights. Perhaps store.sudo.set
      self._commit(txn, callback);
    });
  }

, del: function (path, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'del'
      , args: [path]
      });
      self._commit(txn, callback);
    });
  }

, push: function (path, items, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'push'
      , args: [path].concat(items)
      });
      self._commit(txn, callback);
    });
  }

, unshift: function (path, items, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'unshift'
      , args: [path].concat(items)
      });
      self._commit(txn, callback);
    });
  }

, insert: function (path, index, items, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'insert'
      , args: [path, index].concat(items)
      });
      self._commit(txn, callback);
    });
  }

, pop: function (path, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'pop'
      , args: [path]
      });
      self._commit(txn, callback);
    });
  }

, shift: function (path, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'shift'
      , args: [path]
      });
      self._commit(txn, callback);
    });
  }

, remove: function (path, start, howMany, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'remove'
      , args: [path, start, howMany]
      });
      self._commit(txn, callback);
    });
  }

, move: function (path, from, to, howMany, ver, callback) {
    var self = this;
    self._nextTxnId( function (err, id) {
      var txn = transaction.create({
        ver: ver
      , id: id
      , method: 'move'
      , args: [path, from, to, howMany]
      });
      self._commit(txn, callback);
    });
  }

, incr: function (path, byNum, callback) {
    if (typeof byNum === 'function') {
      // For incr(path, callback)
      callback = byNum;
      byNum = 1;
    } else {
      if (byNum == null) byNum = 1;
    }
    callback || (callback = noop);
    var tryVal;
    this.retry( function (atomic) {
      atomic.get(path, function (val) {
        tryVal = (val || 0) + byNum;
        atomic.set(path, tryVal);
      });
    }, function (err) {
      callback(err, tryVal);
    });
  }

, setNull: function (path, value, callback) {
    callback || (callback = noop);
    var tryVal;
    this.retry( function (atomic) {
      atomic.get(path, function (val) {
        if (val != null) return tryVal = val;
        tryVal = value;
        atomic.set(path, tryVal);
      });
    }, function (err) {
      callback(err, tryVal);
    });
  }

, add: function (path, value, callback) {
    callback || (callback = noop);
    value || (value = {});
    var id = value.id
      , uuid = (this.model && this.model.id || this.uuid)
      , tryId, tryPath;

    this.retry( function (atomic) {
      tryId = id || (value.id = uuid());
      tryPath = path + '.' + tryId;
      atomic.get(tryPath, function (val) {
        if (val != null) return atomic.next('nonUniqueId');
        atomic.set(tryPath, value);
      });
    }, function (err) {
      callback(err, tryId);
    });
  }

, retry: function (fn, callback) {
    var retries = MAX_RETRIES;
    var atomic = new AsyncAtomic(this, function (err) {
      if (!err) return callback && callback();
      if (! retries--) return callback && callback('maxRetries');
      atomic._reset();
      setTimeout(fn, RETRY_DELAY, atomic);
    });
    fn(atomic);
  }
};

var MAX_RETRIES = Async.MAX_RETRIES = 20;
var RETRY_DELAY = Async.RETRY_DELAY = 100;

function AsyncAtomic (async, cb) {
  this.async = async;
  this.cb = cb;
  this.minVer = 0;
  this.count = 0;
}

AsyncAtomic.prototype = {
  _reset: function () {
    this.minVer = 0;
    this.count = 0;
  }

, next: function (err) {
  this.cb(err);
}

, get: function (path, callback) {
    var self = this
      , minVer = self.minVer
      , cb = self.cb
    self.async.get(path, function (err, value, ver) {
      if (err) return cb(err);
      self.minVer = minVer ? Math.min(minVer, ver) : ver;
      callback && callback(value);
    });
  }

, set: function (path, value, callback) {
    var self = this
      , cb = self.cb;
    self.count++;
    self.async.set(path, value, self.minVer, function (err, value) {
      if (err) return cb(err);
      callback && callback(null, value);
      --self.count || cb();
    });
  }

, del: function (path, callback) {
    var self = this
      , cb = self.cb;
    self.count++;
    self.async.del(path, self.minVer, function (err) {
      if (err) return cb(err);
      callback && callback();
      --self.count || cb();
    });
  }
};
