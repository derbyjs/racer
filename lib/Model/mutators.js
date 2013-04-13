var Model = require('./index');

Model.prototype.get = function(path) {
  var at = this._at;
  if (at) {
    path = path ? at + '.' + path : at;
  }
  return this._memory.get(path && path.split('.'));
};

Model.prototype._getDocForMutation = function(segments) {
  var collectionName = segments[0];
  var id = segments[1];
  if (!collectionName || !id) {
    throw new Error(
      'Mutations must be performed under a collection' +
      'and document id. Invalid path:' + segments.join('.')
    );
  }
  return this._memory.getOrCreateDoc(collectionName, id);
};

Model.prototype.set = function(path, value, cb) {
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
  var segments = path.split('.');
  var doc = this._getDocForMutation(segments);
  return doc.set(segments.slice(2), value, cb);
};

// Model.prototype.del = function(path, cb) {

// }

//   , del: {
//       type: BASIC_MUTATOR
//     , fn: function (path, cb) {
//         var at = this._at
//         if (at) {
//           if (typeof path === 'string') {
//             path = at + '.' + path;
//           } else {
//             cb = path;
//             path = at;
//           }
//         }
//         return this._sendOp('del', [path], cb);
//       }
//     }
//   , add: {
//       type: COMPOUND_MUTATOR
//     , fn: function (path, value, cb) {
//         var arglen = arguments.length
//           , id;
//         if (this._at && arglen === 1 || arglen === 2 && typeof value === 'function') {
//           cb = value;
//           value = path;
//           if (typeof value !== 'object') {
//             throw new Error('model.add() requires an object argument');
//           }
//           path = id = value.id || (value.id = this.id());
//         } else {
//           value || (value = {});
//           if (typeof value !== 'object') {
//             throw new Error('model.add() requires an object argument');
//           }
//           id = value.id || (value.id = this.id());
//           path += '.' + id;
//         }

//         if (cb) {
//           this.set(path, value, function (err) { cb(err, id); });
//         } else {
//           this.set(path, value);
//         }
//         return id;
//       }
//     }

//   , setNull: {
//       type: COMPOUND_MUTATOR
//     , fn: function (path, value, cb) {
//         var arglen = arguments.length
//           , obj = (this._at && arglen === 1 || arglen === 2 && typeof value === 'function')
//                 ? this.get()
//                 : this.get(path);
//         if (obj != null) return obj;
//         if (arglen === 1) {
//           this.set(path);
//           return value;
//         }
//         if (arglen === 2) {
//           this.set(path, value);
//           return value;
//         }
//         this.set(path, value, cb);
//         return value;
//       }
//     }

//   , incr: {
//       type: COMPOUND_MUTATOR
//     , fn: function (path, byNum, cb) {
//         if (typeof path !== 'string') {
//           cb = byNum;
//           byNum = path;
//           path = '';
//         }

//         var type = typeof byNum;
//         if (type === 'function') {
//           cb = byNum;
//           byNum = 1;
//         } else if (type !== 'number') {
//           byNum = 1;
//         }
//         var value = (this.get(path) || 0) + byNum;

//         if (path) {
//           this.set(path, value, cb);
//         } else if (cb) {
//           this.set(value, cb);
//         } else {
//           this.set(value);
//         }
//         return value;
//       }
//     }

//   , push: {
//       type: ARRAY_MUTATOR
//     , insertArgs: 1
//     , fn: function () {
//         var args = Array.prototype.slice.call(arguments)
//           , at = this._at
//           , cb;
//         if (at) {
//           var path = args[0]
//             , curr;
//           if (typeof path === 'string' && (curr = this.get()) && !Array.isArray(curr)) {
//             args[0] = at + '.' + path;
//           } else {
//             args.unshift(at);
//           }
//         }

//         if (typeof args[args.length-1] === 'function') {
//           cb = args.pop();
//         }

//         return this._sendOp('push', args, cb);
//       }
//     }

//   , unshift: {
//       type: ARRAY_MUTATOR
//     , insertArgs: 1
//     , fn: function () {
//         var args = Array.prototype.slice.call(arguments)
//           , at = this._at
//           , cb;
//         if (at) {
//           var path = args[0]
//             , curr;
//           if (typeof path === 'string' && (curr = this.get()) && !Array.isArray(curr)) {
//             args[0] = at + '.' + path;
//           } else {
//             args.unshift(at);
//           }
//         }

//         if (typeof args[args.length-1] === 'function') {
//           cb = args.pop();
//         }
//         return this._sendOp('unshift', args, cb);
//       }
//     }

//   , insert: {
//       type: ARRAY_MUTATOR
//     , indexArgs: [1]
//     , insertArgs: 2
//     , fn: function () {
//         var args = Array.prototype.slice.call(arguments)
//           , at = this._at
//           , cb;
//         if (at) {
//           var path = args[0];
//           if (typeof path === 'string' && isNaN(path)) {
//             args[0] = at + '.' + path;
//           } else {
//             args.unshift(at);
//           }
//         }

//         var match = /^(.*)\.(\d+)$/.exec(args[0]);
//         if (match) {
//           // Use the index from the path if it ends in an index segment
//           args[0] = match[1];
//           args.splice(1, 0, match[2]);
//         }

//         if (typeof args[args.length-1] === 'function') {
//           cb = args.pop();
//         }
//         return this._sendOp('insert', args, cb);
//       }
//     }

//   , pop: {
//       type: ARRAY_MUTATOR
//     , fn: function (path, cb) {
//         var at = this._at;
//         if (at) {
//           if (typeof path ===  'string') {
//             path = at + '.' + path;
//           } else {
//             cb = path;
//             path = at;
//           }
//         }
//         return this._sendOp('pop', [path], cb);
//       }
//     }

//   , shift: {
//       type: ARRAY_MUTATOR
//     , fn: function (path, cb) {
//         var at = this._at;
//         if (at) {
//           if (typeof path === 'string') {
//             path = at + '.' + path;
//           } else {
//             cb = path;
//             path = at;
//           }
//         }
//         return this._sendOp('shift', [path], cb);
//       }
//     }

//   , remove: {
//       type: ARRAY_MUTATOR
//     , indexArgs: [1]
//     , fn: function (path, start, howMany, cb) {
//         var at = this._at;
//         if (at) {
//           if (typeof path === 'string' && isNaN(path)) {
//             path = at + '.' + path;
//           } else {
//             cb = howMany;
//             howMany = start;
//             start = path;
//             path = at;
//           }
//         }

//         var match = /^(.*)\.(\d+)$/.exec(path);
//         if (match) {
//           // Use the index from the path if it ends in an index segment
//           cb = howMany;
//           howMany = start;
//           start = match[2]
//           path = match[1];
//         }

//         if (typeof howMany !== 'number') {
//           cb = howMany;
//           howMany = 1;
//         }
//         return this._sendOp('remove', [path, start, howMany], cb);
//       }
//     }

//   , move: {
//       type: ARRAY_MUTATOR
//     , indexArgs: [1, 2]
//     , fn: function (path, from, to, howMany, cb) {
//         var at = this._at;
//         if (at) {
//           // isNaN will be false for index values in a string like '3'
//           if (typeof path === 'string' && isNaN(path)) {
//             path = at + '.' + path;
//           } else {
//             cb = howMany;
//             howMany = to;
//             to = from;
//             from = path;
//             path = at;
//           }
//         }

//         var match = /^(.*)\.(\d+)$/.exec(path);
//         if (match) {
//           // Use the index from the path if it ends in an index segment
//           cb = howMany;
//           howMany = to;
//           to = from;
//           from = match[2];
//           path = match[1];
//         }

//         if (typeof howMany !== 'number') {
//           cb = howMany;
//           howMany = 1;
//         }

//         return this._sendOp('move', [path, from, to, howMany], cb);
//       }
//     }
//   }
// };
