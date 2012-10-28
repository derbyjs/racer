var noop = require('./util').noop
  , Memory = require('./Memory');

/**
 * Transactions are represented as an Array
 * [ ver = vrsion at teh time of the transaction
 * , transaction id
 * , method
 * , arguments]
 */

exports = module.exports = {
  create: function (obj) {
    var txn = (obj.ops) ? [obj.ver, obj.id, obj.ops]
                        : [obj.ver, obj.id, obj.method, obj.args]
      , ctx = obj.context;
    if (ctx && !obj.ops) txn.push({c: ctx});
    return txn;
  }

, getVer: function (txn) { return txn[0]; }
, setVer: function (txn, val) { return txn[0] = val; }

, getId: function (txn) { return txn[1]; }
, setId: function (txn, id) { return txn[1] = id; }

, clientIdAndVer: function (txn) {
    var pair = this.getId(txn).split('.');
    pair[1] = parseInt(pair[1], 10);
    return pair;
  }

, getMethod: function (txn) { return txn[2]; }
, setMethod: function (txn, name) { return txn[2] = name; }

, getArgs: function (txn) { return txn[3]; }
, setArgs: function (txn, vals) { return txn[3] = vals; }
, copyArgs: function (txn) { return this.getArgs(txn).slice(); }

, getPath: function (txn) { return this.getArgs(txn)[0]; }
, setPath: function (txn, val) { return this.getArgs(txn)[0] = val; }

, getMeta: function (txn) { return txn[4]; }
, setMeta: function (txn, meta) { return txn[4] = meta; }

, getContext: function (txn) {
    var meta = this.getMeta(txn);
    return meta && meta.c || 'default';
  }
, setContext: function (txn, ctx) {
    var meta = this.getMeta(txn);
    return meta.c = ctx;
  }

, getClientId: function (txn) {
    return this.getId(txn).split('.')[0];
  }
, setClientId: function (txn, clientId) {
    var pair = this.getId(txn).split('.')
      , clientId = pair[0]
      , num = pair[1];
    this.setId(txn, newClientId + '.' + num);
    return newClientId;
  }

, pathConflict: function (pathA, pathB) {
    // Paths conflict if equal or either is a sub-path of the other
    if (pathA === pathB) return 'equal';
    var pathALen = pathA.length
      , pathBLen = pathB.length;
    if (pathALen === pathBLen) return false;
    if (pathALen > pathBLen)
      return pathA.charAt(pathBLen) === '.' && pathA.substr(0, pathBLen) === pathB && 'child';
    return pathB.charAt(pathALen) === '.' && pathB.substr(0, pathALen) === pathA && 'parent';
  }

, ops: function (txn, ops) {
    if (typeof ops !== 'undefined') txn[2] = ops;
    return txn[2];
  }

, isCompound: function (txn) {
    return Array.isArray(txn[2]);
  }

, applyTxn: function (txn, data, memoryAdapter, ver) {
    return applyTxn(this, txn, data, memoryAdapter, ver);
  }

, op: {
    // Creates an operation
    create: function (obj) { return [obj.method, obj.args]; }

  , getMethod: function (op) { return op[0]; }
  , setMethod: function (op, name) { return op[0] = name; }

  , getArgs: function (op) { return op[1]; }
  , setArgs: function (op, vals) { return op[1] = vals; }

  , applyTxn: function (txn, data, memoryAdapter, ver) {
      return applyTxn(this, txn, data, memoryAdapter, ver);
    }
  }
};

function applyTxn (extractor, txn, data, memoryAdapter, ver) {
  var method = extractor.getMethod(txn);
  if (method === 'get') return;
  var args = extractor.getArgs(txn);
  if (ver !== null) {
    ver = extractor.getVer(txn);
  }
  args = args.concat([ver, data]);
  return memoryAdapter[method].apply(memoryAdapter, args);
}

var transaction = exports;
exports.applyTxnToDoc = (function (memory) {
  memory.setVersion = noop;
  return function (txn, doc) {
    var path = transaction.getPath(txn)
      , parts = path.split('.')
      , ns = parts[0]
      , id = parts[1]

      , world = {}
      , data = { world: world };
    world[ns] = {};
    if (doc) world[ns][id] = doc;

    transaction.applyTxn(txn, data, memory, -1);
    return memory.get(ns + '.' + id, data);
  };
})(new Memory);
