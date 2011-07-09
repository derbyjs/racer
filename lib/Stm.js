var COMMIT, LOCK, LOCK_CLOCK_MASK, LOCK_TIMEOUT, LOCK_TIMEOUT_MASK, MAX_RETRIES, RETRY_DELAY, Stm, UNLOCK, redis, transaction;
var __slice = Array.prototype.slice;
redis = require('redis');
transaction = require('./transaction');
MAX_RETRIES = 10;
RETRY_DELAY = 10;
Stm = module.exports = function() {
  var client, error, getLocks, lock;
  this._client = client = redis.createClient();
  error = function(code, message) {
    var err;
    err = new Error();
    err.code = code;
    err.message = message;
    return err;
  };
  this.flush = function(callback) {
    return this._client.flushdb(callback);
  };
  lock = function(len, locks, base, callback, retries) {
    if (retries == null) {
      retries = MAX_RETRIES;
    }
    return client.eval.apply(client, [LOCK, len].concat(__slice.call(locks), [base], [function(err, values) {
      if (err) {
        throw err;
      }
      if (values[0]) {
        return callback(null, values[0], values[1]);
      }
      if (retries) {
        return setTimeout(function() {
          return lock(len, locks, base, callback, --retries);
        }, (1 << (MAX_RETRIES - retries)) * RETRY_DELAY);
      }
      return callback(error('STM_LOCK_MAX_RETRIES', 'Failed to aquire lock maximum times'));
    }]));
  };
  this._getLocks = getLocks = function(path) {
    var lockPath, segment;
    lockPath = '';
    return ((function() {
      var _i, _len, _ref, _results;
      _ref = path.split('.');
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        segment = _ref[_i];
        _results.push(lockPath += '.' + segment);
      }
      return _results;
    })()).reverse();
  };
  this.commit = function(txn, callback) {
    var base, locks, locksLen;
    locks = getLocks(transaction.path(txn));
    locksLen = locks.length;
    base = transaction.base(txn);
    return lock(locksLen, locks, base, function(err, lockVal, ops) {
      if (err) {
        return callback(err);
      }
      if (transaction.journalConflict(txn, ops)) {
        return client.eval.apply(client, [UNLOCK, locksLen].concat(__slice.call(locks), [lockVal], [function(err) {
          if (err) {
            throw err;
          }
          return callback(error('STM_CONFLICT', 'Conflict with journal'));
        }]));
      }
      return client.eval.apply(client, [COMMIT, locksLen].concat(__slice.call(locks), [lockVal], [JSON.stringify(txn)], [function(err, ver) {
        if (err) {
          throw err;
        }
        if (ver === 0) {
          return callback(error('STM_LOCK_RELEASED', 'Lock was released before commit'));
        }
        return callback(null, ver);
      }]));
    });
  };
};
Stm._LOCK_TIMEOUT = LOCK_TIMEOUT = 3;
Stm._LOCK_TIMEOUT_MASK = LOCK_TIMEOUT_MASK = 0x100000000;
Stm._LOCK_CLOCK_MASK = LOCK_CLOCK_MASK = 0x100000;
Stm._LOCK = LOCK = "local now = os.time()\nlocal path = KEYS[1]\nfor i, val in pairs(redis.call('smembers', path)) do\n  if val % " + LOCK_TIMEOUT_MASK + " < now then\n    redis.call('srem', path, val)\n  else\n    return 0\n  end\nend\nfor i, path in pairs(KEYS) do\n  path = 'l' .. path\n  local val = redis.call('get', path)\n  if val then\n    if val % " + LOCK_TIMEOUT_MASK + " < now then\n      redis.call('del', path)\n    else\n      return 0\n    end\n  end\nend\nlocal val = '0x' ..\n  string.format('%x', redis.call('incr', 'lockClock') % " + LOCK_CLOCK_MASK + ") ..\n  string.format('%x', now + " + LOCK_TIMEOUT + ")\nredis.call('set', 'l' .. path, val)\nfor i, path in pairs(KEYS) do\n  redis.call('sadd', path, val)\nend\nlocal ops = redis.call('zrangebyscore', 'ops', ARGV[1], '+inf')\nreturn {val, ops}";
Stm._UNLOCK = UNLOCK = "local val = ARGV[1]\nlocal path = 'l' .. KEYS[1]\nif redis.call('get', path) == val then redis.call('del', path) end\nfor i, path in pairs(KEYS) do\n  redis.call('srem', path, val)\nend";
Stm._COMMIT = COMMIT = "local val = ARGV[1]\nlocal path = 'l' .. KEYS[1]\nlocal fail = false\nif redis.call('get', path) == val then redis.call('del', path) else fail = true end\nfor i, path in pairs(KEYS) do\n  if redis.call('srem', path, val) == 0 then return 0 end\nend\nif fail then return 0 end\nlocal ver = redis.call('incr', 'ver')\nredis.call('zadd', 'ops', ver - 1, ARGV[2])\nreturn ver";