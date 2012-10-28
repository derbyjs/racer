var EventEmitter = require('events').EventEmitter
  , Serializer = require('../Serializer')
  , transaction = require('../transaction')
  , mergeAll = require('../util').mergeAll
  ;

// When parent model tries to write changes to atomic model,
// then make sure to abort atomic model if any of the changes
// modify paths.

module.exports = function (id, parentModel) {
  function AtomicModel (id, parentModel) {
    this.id = id;
    this.parentModel = parentModel;
    var memory = this._memory = parentModel._memory;
    this.version = memory.version

    this._specCache = {
      invalidate: function () {
        delete this.data;
        delete this.lastTxnId;
      }
    };

    this._opCount = 0;
    this._txns = parentModel._txns;
    this._txnQueue = parentModel._txnQueue.slice(0);

    // Proxy events to the parent model
    var self = this;
    for (var method in EventEmitter.prototype) {
      (function (method) {
        self[method] = function () {
          parentModel[method].apply(parentModel, arguments);
        }
      })(method);
    }
  }

  mergeAll(AtomicModel.prototype, Object.getPrototypeOf(parentModel), proto);

  return new AtomicModel(id, parentModel);
}

var proto = {
  isMyOp: function (id) {
    var extracted = id.substr(0, id.lastIndexOf('.'));
    return extracted === this.id;
  }

, oplog: function () {
    var txns = this._txns
      , txnQueue = this._txnQueue
      , log = [];
    for (var i = 0, l = txnQueue.length; i < l; i++) {
      var id = txnQueue[i];
      if (this.isMyOp(id)) log.push(txns[id]);
    }
    return log;
  }

, _oplogAsTxn: function () {
    var oplog = this.oplog()
      , ops = [];
    for (var i = 0, l = oplog.length; i < l; i++) {
      var txn = oplog[i];
      ops.push( transaction.op.create({
        method: transaction.getMethod(txn)
      , args: transaction.getArgs(txn)
      }) );
    }
    return transaction.create({ver: this.version, id: this.id, ops: ops});
  }

, _getVersion: function () { return this.version; }

, commit: function (callback) {
    var txn = this._oplogAsTxn()
      , parentModel = this.parentModel;
    parentModel._queueTxn(txn, callback);
    parentModel._commit(txn);
  }

, get: function (path) {
    var memory = this._memory
      , val = memory.get(path, this._specModel())
      , ver = memory.version;
    if (ver <= this.version) this._addOpAsTxn('get', [path]);
    return val;
  }

, _nextTxnId: function () { return this.id + '.' + (++this._opCount); }

, _conflictsWithMe: function (txn) {
    var txns = this._txns
      , ver = this.version
      , txnQueue = this._txnQueue;
    for (var i = 0, l = txnQueue.length; i < l; i++) {
      var id = txnQueue[i]
        , myTxn = txns[id];
      if (this.isMyOp(id) && transaction.pathConflict(txn, myTxn) && ver < transaction.getVer(txn)) {
        return true;
      }
    }
    return false;
  }
};
