var Async = require('./Async')
  , Memory = require('../Memory')
  , ACCESSOR = 'accessor'
  , BASIC_MUTATOR = 'mutator,basicMutator'
  , COMPOUND_MUTATOR = 'mutator,compoundMutator'
  , ARRAY_MUTATOR = 'mutator,arrayMutator'
  ;

module.exports = {
  type: 'Model'

, static: {
    ACCESSOR: ACCESSOR
  , BASIC_MUTATOR: BASIC_MUTATOR
  , COMPOUND_MUTATOR: COMPOUND_MUTATOR
  , ARRAY_MUTATOR: ARRAY_MUTATOR
  }

, events: {
    init: function (model) {
      // Memory instance for use in building multiple path objects in async get
      var memory = new Memory();

      model.async = new Async({
        model: model

      , nextTxnId: function () { return model._nextTxnId(); }

      , get: function (path, cb) {
          model._upstreamData([path], function (err, data) {
            if (err) return cb(err);

            // Callback with undefined if no data matched
            var items = data.data
              , len = items && items.length;
            if (! len) return cb();

            // Callback with the value for a single matching item on the same
            // path
            if (len === 1) {
              var item = items[0];
              if (item && item[0] === path) {
                return cb(null, item[1]);
              }
            }

            // Callback with a multiple path object, such as the result of a query
            for (var i = 0, l = items.length; i < l; i++) {
              var pair = items[i]
                , subpath = pair[0]
                , value = pair[1];
              memory.set(subpath, value, -1);
            }
            var out = memory.get(path);
            memory.flush();
            cb(null, out);
          });
        }

      , commit: function (txn, cb) { model._asyncCommit(txn, cb); }
      });
    }
  }

, proto: {
    get: {
      type: ACCESSOR
    , fn: function (path) {
        var at = this._at;
        if (at) {
          path = path ? at + '.' + path : at;
        }
        return this._memory.get(path, this._specModel());
      }
    }

  , set: {
      type: BASIC_MUTATOR
    , fn: function (path, value, cb) {
        var at = this._at;
        if (at) {
          var arglen = arguments.length;
          if (arglen === 1 || arglen === 2 && typeof value === 'function') {
            cb = value;
            value = path;
            path = at
          } else {
            path = at + '.' + path;
          }
        }

        // Replace special unicode characters that cause a Syntax Error ILLEGAL
        // in v8 and chromium
        // http://timelessrepo.com/json-isnt-a-javascript-subset
        // http://code.google.com/p/v8/issues/detail?can=2&start=0&num=100&q=&colspec=ID%20Type%20Status%20Priority%20Owner%20Summary%20HW%20OS%20Area%20Stars&groupby=&sort=&id=1939
        if (typeof value === 'string') {
          value = value.replace(/\u2028/g, "\n").replace(/\u2029/g, "\n");
        }
        return this._sendToMiddleware('set', [path, value], cb);
      }
    }

  , del: {
      type: BASIC_MUTATOR
    , fn: function (path, cb) {
        var at = this._at
        if (at) {
          if (typeof path === 'string') {
            path = at + '.' + path;
          } else {
            cb = path;
            path = at;
          }
        }
        return this._sendToMiddleware('del', [path], cb);
      }
    }
  , add: {
      type: COMPOUND_MUTATOR
    , fn: function (path, value, cb) {
        var arglen = arguments.length
          , id;
        if (this._at && arglen === 1 || arglen === 2 && typeof value === 'function') {
          cb = value;
          value = path;
          if (typeof value !== 'object') {
            throw new Error('model.add() requires an object argument');
          }
          path = id = value.id || (value.id = this.id());
        } else {
          value || (value = {});
          if (typeof value !== 'object') {
            throw new Error('model.add() requires an object argument');
          }
          id = value.id || (value.id = this.id());
          path += '.' + id;
        }

        if (cb) {
          this.set(path, value, function (err) { cb(err, id); });
        } else {
          this.set(path, value);
        }
        return id;
      }
    }

  , setNull: {
      type: COMPOUND_MUTATOR
    , fn: function (path, value, cb) {
        var arglen = arguments.length
          , obj = (this._at && arglen === 1 || arglen === 2 && typeof value === 'function')
                ? this.get()
                : this.get(path);
        if (obj != null) return obj;
        if (arglen === 1) {
          this.set(path);
          return value;
        }
        if (arglen === 2) {
          this.set(path, value);
          return value;
        }
        this.set(path, value, cb);
        return value;
      }
    }

  , incr: {
      type: COMPOUND_MUTATOR
    , fn: function (path, byNum, cb) {
        if (typeof path !== 'string') {
          cb = byNum;
          byNum = path;
          path = '';
        }

        var type = typeof byNum;
        if (type === 'function') {
          cb = byNum;
          byNum = 1;
        } else if (type !== 'number') {
          byNum = 1;
        }
        var value = (this.get(path) || 0) + byNum;

        if (path) {
          this.set(path, value, cb);
        } else if (cb) {
          this.set(value, cb);
        } else {
          this.set(value);
        }
        return value;
      }
    }

  , push: {
      type: ARRAY_MUTATOR
    , insertArgs: 1
    , fn: function () {
        var args = Array.prototype.slice.call(arguments)
          , at = this._at
          , cb;
        if (at) {
          var path = args[0]
            , curr;
          if (typeof path === 'string' && (curr = this.get()) && !Array.isArray(curr)) {
            args[0] = at + '.' + path;
          } else {
            args.unshift(at);
          }
        }

        if (typeof args[args.length-1] === 'function') {
          cb = args.pop();
        }

        return this._sendToMiddleware('push', args, cb);
      }
    }

  , unshift: {
      type: ARRAY_MUTATOR
    , insertArgs: 1
    , fn: function () {
        var args = Array.prototype.slice.call(arguments)
          , at = this._at
          , cb;
        if (at) {
          var path = args[0]
            , curr;
          if (typeof path === 'string' && (curr = this.get()) && !Array.isArray(curr)) {
            args[0] = at + '.' + path;
          } else {
            args.unshift(at);
          }
        }

        if (typeof args[args.length-1] === 'function') {
          cb = args.pop();
        }
        return this._sendToMiddleware('unshift', args, cb);
      }
    }

  , insert: {
      type: ARRAY_MUTATOR
    , indexArgs: [1]
    , insertArgs: 2
    , fn: function () {
        var args = Array.prototype.slice.call(arguments)
          , at = this._at
          , cb;
        if (at) {
          var path = args[0];
          if (typeof path === 'string' && isNaN(path)) {
            args[0] = at + '.' + path;
          } else {
            args.unshift(at);
          }
        }

        var match = /^(.*)\.(\d+)$/.exec(args[0]);
        if (match) {
          // Use the index from the path if it ends in an index segment
          args[0] = match[1];
          args.splice(1, 0, match[2]);
        }

        if (typeof args[args.length-1] === 'function') {
          cb = args.pop();
        }
        return this._sendToMiddleware('insert', args, cb);
      }
    }

  , pop: {
      type: ARRAY_MUTATOR
    , fn: function (path, cb) {
        var at = this._at;
        if (at) {
          if (typeof path ===  'string') {
            path = at + '.' + path;
          } else {
            cb = path;
            path = at;
          }
        }
        return this._sendToMiddleware('pop', [path], cb);
      }
    }

  , shift: {
      type: ARRAY_MUTATOR
    , fn: function (path, cb) {
        var at = this._at;
        if (at) {
          if (typeof path === 'string') {
            path = at + '.' + path;
          } else {
            cb = path;
            path = at;
          }
        }
        return this._sendToMiddleware('shift', [path], cb);
      }
    }

  , remove: {
      type: ARRAY_MUTATOR
    , indexArgs: [1]
    , fn: function (path, start, howMany, cb) {
        var at = this._at;
        if (at) {
          if (typeof path === 'string' && isNaN(path)) {
            path = at + '.' + path;
          } else {
            cb = howMany;
            howMany = start;
            start = path;
            path = at;
          }
        }

        var match = /^(.*)\.(\d+)$/.exec(path);
        if (match) {
          // Use the index from the path if it ends in an index segment
          cb = howMany;
          howMany = start;
          start = match[2]
          path = match[1];
        }

        if (typeof howMany !== 'number') {
          cb = howMany;
          howMany = 1;
        }
        return this._sendToMiddleware('remove', [path, start, howMany], cb);
      }
    }

  , move: {
      type: ARRAY_MUTATOR
    , indexArgs: [1, 2]
    , fn: function (path, from, to, howMany, cb) {
        var at = this._at;
        if (at) {
          // isNaN will be false for index values in a string like '3'
          if (typeof path === 'string' && isNaN(path)) {
            path = at + '.' + path;
          } else {
            cb = howMany;
            howMany = to;
            to = from;
            from = path;
            path = at;
          }
        }

        var match = /^(.*)\.(\d+)$/.exec(path);
        if (match) {
          // Use the index from the path if it ends in an index segment
          cb = howMany;
          howMany = to;
          to = from;
          from = match[2];
          path = match[1];
        }

        if (typeof howMany !== 'number') {
          cb = howMany;
          howMany = 1;
        }

        return this._sendToMiddleware('move', [path, from, to, howMany], cb);
      }
    }
  }
};
